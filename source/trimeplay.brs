' trimePlay
' This was written in less than a week after I decided I would really like to view photos from my recent holiday on my TV
' So don't expect that much ;)

' The key to understanding this nightmare of spaghetti is as follows:
' Brightscript is single-threaded. Therefore nothing may block
' Everything is a finite state machine. When data arrives on a socket then we look up the FSM for that socket, and call
' appropriate function to parse from (or write) to the socket.
' There are 4 kinds of these machines:
'   * UDP messages, which handle mDNS to announce the roku on the network. Handled in mdns.brs
'   * HTTP connections *from* the iDevice. These are like POST /play and GET /scrub. handled in http_reply.brs
'   * HTTP connection replies to messages sent via the reverse HTTP (typically these are not very interesting, but must be handled)
'   * HTTP connection replies to MP4 data requests. These are more interesting, and are handled in mp4.brs



Function Main()
    msgPort = createobject("roMessagePort") 
    m.mac = "CA:FE:BA:BE:FA:17"                 ' FIXME: fake?
    m.features = "3"
    'm.features = "0x39f7"
    ' Set up some stuff so we can display screens later in the http handlers

    m.port = msgPort
    m.state = "none"
    m.video_state = 0
    m.video_position = 0

    device_info = createobject("roDeviceInfo")
    m.display_size = device_info.getDisplaySize()

    default_screen = createobject("roImageCanvas")
    default_screen.SetMessagePort(msgPort)
    default_screen.SetLayer(0, {Color:"#FF000000", CompositionMode:"Source"}) 
    default_screen.SetLayer(1, {text:"Waiting for connection"
                           TextAttrs:{Color:"#FFCCCCCC", Font:"Medium",
                                     HAlign:"HCenter", VAlign:"VCenter",
                                  Direction:"LeftToRight"}
                                 TargetRect:{x:0,y:0,w:m.display_size.w,h:m.display_size.h}})

    default_screen.show()

    m.reversals = {}
    http_replies = {}
    m.mp4_connections = {}
    m.connections = {}
    http_requests = {}
    udp = createobject("roDatagramSocket")
    udp.setMessagePort(msgPort)

    udp_bind_addr = createobject("roSocketAddress")
    udp_bind_addr.setPort(5353)
    udp.setAddress(udp_bind_addr) 

    group = createobject("roSocketAddress")
    group.setHostName("224.0.0.251")
    result = udp.joinGroup(group)
    udp.setMulticastLoop(false)

    ' Set up the about-to-be-advertised TCP socket
    tcp = createobject("roStreamSocket")
    tcp.setMessagePort(msgPort)
    tcp_bind_addr = CreateObject("roSocketAddress")
    tcp_bind_addr.setPort(7000)
    tcp.setAddress(tcp_bind_addr)
    tcp.notifyReadable(true)
    tcp.listen(4)
    if not tcp.eOK() 
        print "Could not create TCP socket"
        stop
    end if

    ' Set up the unadvertised mirroring TCP socket just for fun
    mirror = createobject("roStreamSocket")
    mirror.setMessagePort(msgPort)
    mirror_bind_addr = CreateObject("roSocketAddress")
    mirror_bind_addr.setPort(7100)
    mirror.setAddress(mirror_bind_addr)
    mirror.notifyReadable(true)
    mirror.listen(4)
    if not mirror.eOK() 
        print "Could not create mirror TCP socket"
        stop
    end if


    ' Need to broadcast that we are an Apple TV, rather than just waiting to be polled. Sometimes this helps
    udp.setBroadcast(true)
    addr = createobject("roSocketAddress")
    addr.setPort(5353)
    addr.setHostName("224.0.0.251")
    udp.setSendToAddress(addr)
    announce = announce_packet()    
    print "Announcing our existence to the network"
    result = udp.send(announce, 0, announce.Count())
    udp.notifyReadable(true) 
    While true
        'print "Waiting in main loop"
        event = wait(0, msgPort)
        If type(event)="roSocketEvent"
            'print "Got event on " ; event.getSocketID()
            If event.getSocketID() = udp.getID()
                If udp.isReadable()
                   message = createobject("roByteArray")
                   size = udp.getCountRcvBuf()
                   ' Work around bug in upd.receive() :-S
                   message[size] = 0
                   message[size] = invalid
                   udp.receive(message, 0, size)
                   from = udp.getReceivedFromAddress()
                   'print "Received message of length " ; str(size) ; " from " ; from.getAddress()
                   dns = parse_dns(message)
                   respond_to_dns(dns, udp)
                End If
            Else If event.getSocketID() = tcp.getID()
                 client = tcp.accept()
                 If client = Invalid
                     print "Accept failed"                   
                 Else
                     client.notifyReadable(true)
                     client.setMessagePort(msgPort)
                     m.connections[Stri(client.getID())] = client
                End If
            Else if event.getSocketID() = mirror.getID()
                 print "MIRRORING CONNECTION?"
                 client = mirror.accept()
                 If client = Invalid
                     print "Accept failed"                   
                 Else
                     client.notifyReadable(true)
                     client.setMessagePort(msgPort)
                     m.connections[Stri(client.getID())] = client
                End If
            Else
                ' Must be a client connection!
                connection = m.connections[Stri(event.getSocketID())]
                ' If connection is invalid, what does that mean?
                if connection <> invalid
                    ' FIXME: Is this still right since I added the mp4 stuff? Do we actually correctly close sockets?
                    if connection.isReadable() and connection.getCountRcvBuf() = 0 and not connection.isWritable() Then
                        ' Apparently this means the connection has been closed
                        ' What a terrible way to indicate it
                        print "Connection is closed"
                        connection.close()
                        m.connections[Stri(event.getSocketID())] = invalid
                    Else
                        handle_tcp(connection, http_requests, http_replies)
                    End If
                else 
                    print "Invalid connection"
                End If
            End If
        Else If type(event)="roVideoScreenEvent" Then
            if event.isStreamStarted()
               m.video_state = 1 ' playing
               send_event("state", "playing")
               m.video_position = event.GetIndex()
            else if event.isPlaybackPosition()
               m.video_position = event.GetIndex()
            else if event.isPaused()
               m.video_state = 2 'paused
               send_event("state", "paused")
            else if event.isResumed()
               send_event("state", "playing")
               m.video_state = 1 ' playing
            End If
            'print "Position is now "; m.video_position 
        Else
            print "Unexpected event: " ; type(event)
        End If
    End While
    udp.close()
End Function


Sub handle_tcp(connection as Object, http_requests as Object, http_replies as Object)
    If m.reversals[Stri(connection.getID())] <> invalid Then
        ' Data arriving on reverse connection
        if connection.getCountRcvBuf() = 0 Then
            connection.close()
            m.reversals[Stri(connection.getID())] = invalid
        else
            reply = http_replies[Stri(connection.getID())]
            if reply = invalid Then
                reply = create_new_reply()
            end if
            is_complete = read_http_reply(connection, reply)
            if is_complete then
                print "Got reply. Status was " ; reply.status
                read_http_reply(connection, reply)
                http_replies[Stri(connection.getID())] = invalid
            End if
        end if
    Else if m.mp4_connections[Stri(connection.getID())] <> invalid Then
        ' A response to an MP4 data request
        request = m.mp4_connections[Stri(connection.getID())]
        if request.state = -1 then
            print "Sending mp4 request"
            send_mp4_request(connection, request.path, "0", "1024")
        else
            is_complete = read_http_reply(connection, request)
            if is_complete then
                handle_mp4_data(connection, request)
            end if
        end if
    Else
        ' A request from the iDevice
        request = http_requests[Stri(connection.getID())]
        If request = invalid Then
           'print "New request on socket"
           request = create_new_request()
           http_requests[Stri(connection.getID())] = request
        End If
        is_complete = read_http(connection, request)
        If is_complete Then
            dispatch_http(request, connection)
            ' Mark as finished
            http_requests[Stri(connection.GetID())] = invalid
        end if
    End If
End Sub


Sub load_video_parameters(hostname as String, port as integer, path as String)
    socket = createobject("roStreamSocket")
    socket.setMessagePort(m.port)
    mp4_addr = CreateObject("roSocketAddress")
    mp4_addr.setPort(port)
    mp4_addr.setHostName(hostname)      
    request = create_new_request()
    m.mp4_connections[Stri(socket.getID())] = request
    m.mp4_connections[Stri(socket.getID())].state = -1 ' unconnected
    m.connections[Stri(socket.getID())] = socket
    request.path = path
    socket.setSendToAddress(mp4_addr)
    socket.notifyReadable(true)
    socket.notifyWritable(true)
    print "Connecting to get mp4 data on " ; socket.getID()
    socket.connect()
    'send_mp4_request(socket, path, 0, 1024)
End Sub

' We have to keep the ranges as strings, since brightscript will coerce them to floats, and print them out in scientific notation
' which iOS does not care for. Worse, because we lose precision, we cannot reliably get it back
' add_strings() below adds two strings
Sub send_mp4_request(socket as Object, path as string, start_range as string, end_range as string)    
    reply = create_new_reply()
    m.mp4_connections[Stri(socket.getID())] = reply
    reply.start_range = start_range
    reply.path = path
    packet = createobject("roByteArray")

    packet.fromAsciiString("GET " + path + " HTTP/1.1" + chr(13) + chr(10) + "Range: bytes=" + start_range +"-" + end_range + chr(13) + chr(10) + chr(13) + chr(10))
    socket.send(packet, 0, packet.Count())
End Sub
