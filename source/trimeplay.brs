Function Main()
    msgPort = createobject("roMessagePort") 
    m.mac = "CA:FE:BA:BE:FA:17"                 ' FIXME: fake?
    m.features = "3" '0x93
    'm.features = "0x39f7"

    ' Set up some stuff so we can display screens later in the http handlers
    m.port = msgPort
    m.state = "none"
    m.video_paused = true
    m.video_position = 0

    m.reversals = {}
    connections = {}
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

    ' Set up the advertised TCP socket
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

    ' Set up the unadvertised mirroring TCP socket
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


    ' Need to broadcast that we are an Apple TV, rather than just waiting to be polled
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
                     connections[Stri(client.getID())] = client
                End If
            Else if event.getSocketID() = mirror.getID()
                 print "MIRRORING"
                 client = mirror.accept()
                 If client = Invalid
                     print "Accept failed"                   
                 Else
                     client.notifyReadable(true)
                     client.setMessagePort(msgPort)
                     connections[Stri(client.getID())] = client
                End If
            Else
                ' Must be a client connection!
                connection = connections[Stri(event.getSocketID())]
                ' If connection is invalid, what does that mean?
                if connection <> invalid and connection.isReadable()
                    if connection.getCountRcvBuf() = 0 Then
                        ' Apparently this means the connection has been closed
                        ' What a terrible way to indicate it
                        connection.close()
                        connections[Stri(event.getSocketID())] = invalid
                    Else
                        handle_tcp(connection, http_requests)
                    End If
                End If
            End If
        Else If type(event)="roVideoScreenEvent" Then
            if event.isStreamStarted()
               print "isStarted"
               if m.video_paused then
                   m.screen.Pause()
               end if
               m.video_position = event.GetIndex()
            else if event.isPlaybackPosition()
               print "isPlaybackPosition"
               m.video_position = event.GetIndex()
            else if event.isPaused()
               print "isPaused"
               m.video_paused = true
            else if event.isResumed()
               print "isResumed"
               m.video_paused = false            
            End If
            print "Position is now "; m.video_position 
        Else
            print "Unexpected event: " ; type(event)
        End If
    End While
    udp.close()
End Function


Sub handle_tcp(connection as Object, http_requests as Object)
    ' Ignore anything which is doing reverse HTTP
    If m.reversals[Stri(connection.getID())] = invalid Then
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
    Else
        print "Reversal action"
    End If
End Sub

Sub respond_to_dns(dns as Object, udp as Object)
    For Each question in dns["questions"]
        uri = ""
        For Each part in question
            uri = uri + part + "."
        End For
        'print "Query received for " ; uri
        If uri = "_raop._tcp.local." or uri = "._airplay." or uri = "_services._dns-sd._udp.local." Then
            announce = announce_packet()
            result = udp.send(announce, 0, announce.Count())
        End If
    End For
End Sub

Function parse_question(message as Object, questions as Object, history as Object, n as integer)
    parts = []
    length = message.Shift()
    n = n + 1
    While length <> 0
        part = ""
        If length = 192
           ' This is a pointer-type record, which is horrifically difficult for me to parse
           offset = message.Shift() ' FIXME: Does not take into account low-15 bytes of first byte
           n = n + 1
           For i = offset To history.count() Step 1
               If history[i] = "" 
                  Exit For
               End If
               If history[i] <> invalid
                  parts.push(history[i])
               End If
           End For
           Exit While
        Else
            For i = 1 To length
                part = part + chr(message.Shift())
            End For
        End If
        parts.push(part)
        history[n] = part
        length = message.Shift()
        n = n + 1
    End While
    history[n] = ""

    record_type = message.Shift() * 256 + message.Shift()
    class = message.Shift() * 256 + message.Shift()
    n = n + 4
    questions.push(parts)
    return n
End Function

Function parse_dns(message as Object)
   id = 256 * message.Shift() + message.Shift()
   flags = 256 * message.Shift() + message.Shift()
   qd_count = 256 * message.Shift() + message.Shift()
   an_count = 256 * message.Shift() + message.Shift()
   ns_count = 256 * message.Shift() + message.Shift()
   ar_count = 256 * message.Shift() + message.Shift()

   questions = []
   history = []
   n = 12
   For i = 1 To qd_count Step 1
       n = parse_question(message, questions, history, n)
   End For


   return {id: id
           flags: flags
           questions: questions}
End Function

Function announce_packet()
    announce = CreateObject("roByteArray")
    
    device_info = createobject("roDeviceInfo")
    addresses = device_info.GetIPAddrs()
    ip_addresses = []
    For each address in addresses
        ip = addresses[address]
        this_address = createobject("roByteArray")
        ipbytes = createobject("roByteArray")
        ipbytes.fromAsciiString(ip)
        digit = 0
        For each byte in ipbytes
            if byte = 46
               this_address.push(digit)
               digit = 0
            Else
                digit = digit * 10 + (byte - 48)
            End If
        End For
        this_address.Push(digit)
        ip_addresses.Push(this_address)
    End For

    ' Write ID 
    announce[0] = 0
    announce[1] = 0
    ' Write flags
    announce[2] = 132 '0x84
    announce[3] = 0

    ' 1 Questions
    announce[4] = 0
    announce[5] = 1
    ' 5 Answer RRs
    announce[6] = 0
    announce[7] = 8
    ' 0 Authority RRs
    announce[8] = 0
    announce[9] = 0
    ' 1 Additional RRs
    announce[10] = 0
    announce[11] = ip_addresses.count()
    
    encode_questions(announce, [["roku", "_airplay", "_tcp", "local"]])
'-----------------------------------------------------------------------------------------------------------
    data = [{qname:["roku", "_airplay", "_tcp", "local"],
              text:["deviceid=" + m.mac,
                    "features=" + m.features,
                    "model=AppleTV2,1"
                    "srcvers=101.28"]},

            {qname:["CAFEBABEFA17@roku", "_raop", "_tcp", "local"],
              text:["txtvers=1"
                    "ch=2"
                    "cn=0,1,2,3"
                    "da=true"
                    "et=0,3,5"
                    "md=0,1,2"
                    "pw=false"
                    "sv=false"
                    "sr=44100"
                    "ss=16"
                    "tp=UDP"
                    "vn=65537"
                    "vs=130.14"
                    "am=AppleTV2,1"
                    "sf=0x4"]},

            {qname:["_services", "_dns-sd", "_udp", "local"],
               ptr:["_airplay", "_tcp", "local"]},

            {qname:["_services", "_dns-sd", "_udp", "local"],
               ptr:["_raop", "_tcp", "local"]},

            {qname:["_airplay", "_tcp", "local"],
               ptr:["roku", "_airplay", "_tcp", "local"]},

            {qname:["_raop", "_tcp", "local"],
               ptr:["CAFEBABEFA17@roku", "_raop", "_tcp", "local"]},

            {qname:["roku", "_airplay", "_tcp", "local"],
           service:{port:7000,
                hostname:["roku", "local"]}},
  
            {qname:["CAFEBABEFA17@roku", "_raop", "_tcp", "local"],
           service:{port:7100,
                hostname:["roku", "local"]}}]


    For Each ip in ip_addresses
        data.push({qname:["roku", "local"],
                       a:ip})
    End For
    encode_answers(announce, data)
                                 
    return announce
End Function


Sub encode_questions(announce as Object, questions as Object)
    For Each question in questions
        encode_qname(announce, question)
        ' Set the type to ANY
        announce.Push(0)
        announce.Push(255)

        ' Set the class to IN, QU = false
        announce.Push(0)
        announce.Push(1)       
    End For
End Sub


Sub encode_answers(announce as Object, answers as Object)
    For Each answer in answers
        encode_qname(announce, answer["qname"])
        If answer["service"] <> invalid
           encode_service(announce, answer["service"])
        Else If answer["ptr"] <> invalid
           encode_ptr(announce, answer["ptr"])
        Else If answer["text"] <> invalid
           encode_text(announce, answer["text"])
        Else If answer["a"] <> invalid
           encode_host(announce, answer["a"])
        End If
    End For
End Sub


Sub encode_ptr(announce as Object, auth as Object)
    ' Set the type to PTR
    announce.Push(0)
    announce.Push(12)

    ' Set the class to IN
    announce.Push(0)
    announce.Push(1)        

    ' TTL is 1:15:00
    announce.Push(0)
    announce.Push(0)
    announce.Push(17)
    announce.Push(148)

    ' Store the length
    length = auth.Count() + 1
    For Each chunk In auth
        length = length + len(chunk)
    End For
    announce.Push(length / 256)

    announce.Push(length MOD 256)
    
    encode_qname(announce, auth)
End Sub

Sub encode_host(announce as Object, auth as Object)
    ' Set the type to A
    announce.Push(0)
    announce.Push(1)

    ' Set the class to IN
    announce.Push(0)
    announce.Push(1)        

    ' TTL is 120s
    announce.Push(0)
    announce.Push(0)
    announce.Push(0)
    announce.Push(120)

    ' Store the length
    announce.Push(0)
    announce.Push(4)

    For Each chunk In auth
        announce.Push(chunk)
    End For
End Sub
    


Sub encode_service(announce as Object, auth as Object)
    ' Set the type to SRV
    announce.Push(0)
    announce.Push(33)

    ' Set the class to IN
    announce.Push(0)
    announce.Push(1)        

    ' TTL is 120s
    announce.Push(0)
    announce.Push(0)
    announce.Push(0)
    announce.Push(120)

    ' Store the length
    length = auth["hostname"].Count() + 1
    For Each chunk In auth["hostname"]
        length = length + len(chunk)
    End For
    length = length + 6 ' Add space for priority, weight and port
    announce.Push(length / 256)
    announce.Push(length MOD 256)
    
    ' Priority 0
    announce.push(0)
    announce.push(0)

    ' Weight 0
    announce.push(0)
    announce.push(0)

    ' Port
    announce.push(auth["port"] / 256)
    announce.push(auth["port"] MOD 256)     

    ' Hostname
    encode_qname(announce, auth["hostname"])
End Sub

Sub encode_text(announce as Object, texts as Object)
    ' Set the type to TXT
    announce.Push(0)
    announce.Push(16)

    ' Set the class to IN
    announce.Push(0)
    announce.Push(1)        

    ' TTL is 1:15:00
    announce.Push(0)
    announce.Push(0)
    announce.Push(17)
    announce.Push(148)

    ' Store the length
    length = texts.Count()
    For Each chunk In texts
        length = length + len(chunk)
    End For
    announce.Push(length / 256)
    announce.Push(length MOD 256)

    For Each chunk In texts
        announce.Push(len(chunk))
        bytes = createobject("roByteArray")
        bytes.fromAsciiString(chunk)
        For Each byte In bytes
            announce.Push(byte)
        End For
    End For    
End Sub



Sub encode_qname(announce as Object, items as Object)
    For Each item In items
        bytes = createobject("roByteArray")
        bytes.fromAsciiString(item)
        announce.Push(bytes.Count())
        For Each byte In bytes
            announce.Push(byte)
        End For
    End For
    announce.Push(0) ' End of qname
End Sub
