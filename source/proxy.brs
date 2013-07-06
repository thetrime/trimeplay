Function handle_proxy(http as Object, connection as Object)
    ' Ok. First, get a handle to the original connection
    real_url = parse_url(http.search["original_url"])
    delta = http.search["delta"]
    if delta = invalid then
       delta = 0
    end if
    socket = createobject("roStreamSocket")
    socket.setMessagePort(GetGlobalAA().port)
    mp4_addr = CreateObject("roSocketAddress")
    mp4_addr.setPort(real_url.port)
    mp4_addr.setHostName(real_url.hostname)      
    reply = create_new_reply()
    GetGlobalAA().sockets[Stri(socket.getID())] = socket
    GetGlobalAA().connections[Stri(socket.getID())] = reply    
    reply.read_data = send_proxy_request
    reply.slave = connection
    reply.url = real_url
    reply.delta = delta
    socket.setSendToAddress(mp4_addr)
    socket.notifyReadable(true)
    socket.notifyWritable(true)
    print "Connecting to get proxy data on " ; socket.getID()
    socket.connect()
End Function

Function send_proxy_request(request as Object, socket as Object)
    if socket.eOK() and socket.isWritable() then
        socket.notifyWritable(false) 'shut up shut up SHUT UP!
        print "Sending proxy fetch on " ; socket.getID()
        reply = create_new_reply()
        reply.body_handler = proxy_data
        reply.process_data = finished_proxy
        reply.proxy_state = 0
        reply.unsent_buffers = []
        GetGlobalAA().connections[Stri(socket.getID())] = reply
        reply.url = request.url
        reply.slave = request.slave
        reply.slave.notifyReadable(false)
        reply.sent = 0
        reply.delta = request.delta
        slave_connection = create_new_reply()
        slave_connection.read_data = flush_proxy
        slave_connection.source = reply

        GetGlobalAA().connections[Stri(reply.slave.getID())] = slave_connection

        packet = createobject("roByteArray")
        msg = "GET " + request.url.path + " HTTP/1.1" + chr(13) + chr(10) + "Host: " + request.url.hostname + chr(13) + chr(10) + "User-agent: QuickTime" + chr(13) + chr(10) + chr(13) + chr(10)
        print msg
        packet.fromAsciiString(msg)
        socket.send(packet, 0, packet.Count())
        return false
    Else
        ' They hung up on us! This should NOT happen!
        print "Hangup detected?"
        stop
    End If
End Function

Function finished_proxy(reply as Object, connection as Object)
    return true
End Function

Function flush_proxy(reply as Object, connection as Object)
    source = reply.source
    'print "-------------------------Flushing at " ; source.sent
    While source.unsent_buffers.count() > 0 and connection.isWritable()
        buffer = source.unsent_buffers[0].buffer
        length = source.unsent_buffers[0].buffer.count() - source.unsent_buffers[0].from
        'debug_buffer("case 1", buffer, source.unsent_buffers[0].from)
        sent = connection.send(buffer, source.unsent_buffers[0].from, length)
        if sent = length then
           source.sent = source.sent + sent
           source.unsent_buffers.shift()
        else if sent = -1 then      
            if connection.eWouldBlock()
                return false ' We just have to try again later
            end if            
            print connection.status()
            print connection.eOK()
            print connection.eWouldBlock()
            print connection.eSuccess()
            stop
        else
           source.sent = source.sent + sent
           source.unsent_buffers[0].from = source.unsent_buffers[0].from + sent
           return false
        end if        
    End While
    if source.unsent_buffers.count() = 0 then
        ' We have successfully flushed the entire queue! Therefore we no longer care if we are writable
        connection.notifyWritable(false)
    else
        ' There are pending buffers. We want to know when time is up
        connection.notifyWritable(true)
    end if
    return false
End Function

Function proxy_data(reply as Object, connection as Object)
    ' reply.buffer contains some data. If we are finished proxying, set reply.state to 7.
    if reply.proxy_state = 0 then
        ' Send headers
        reply.slave.sendStr("HTTP/1.1 200 OK" + chr(13) + chr(10))
        for each header in reply.headers
            if reply.delta <> 0 and header = "content-length" Then
                reply.slave.sendStr(header + ": " + add_strings(delta, reply.headers[header]) + chr(13) + chr(10))
            else
                reply.slave.sendStr(header + ": " + reply.headers[header] + chr(13) + chr(10))
            end if
        end for
        reply.slave.sendStr(chr(13) + chr(10))
        reply.proxy_state = 1
    end if
    flush_proxy({source:reply}, reply.slave)
    if reply.buffer.count() > 0 then
        'print "Buffer contains " ; reply.buffer.count() ; " bytes"
        if reply.slave.isWritable() then
            'print "-------------------------Case 2 at " ; reply.sent
            'debug_buffer("case 3", reply.buffer, 0)
            sent = reply.slave.send(reply.buffer, 0, reply.buffer.count())
            'print sent
        else
            sent = 0
        end if
        if sent = -1 and reply.slave.eWouldBlock() then
            sent = 0
        else if sent = -1 then
            stop
        end if
        reply.sent = reply.sent + sent
        if sent < reply.buffer.count() then
            'print "Only sent " ; sent ; " bytes out of " ; reply.buffer.count()
            reply.slave.notifyWritable(true)
            ' Save some for later. Who knows how incredibly inefficient this is?
            backing_buffer = createobject("roByteArray")
            backing_buffer.append(reply.buffer)
            'print "Adding new unsent buffer, starting from " ; sent
            reply.unsent_buffers.push({buffer: backing_buffer,
                                         from: sent})
        else
            print "All pending data flushed!"
        end if
        reply.body_size = reply.body_size + reply.buffer.count()-1
    else
        print "No data?"
    end if
    if reply.body_size >= reply.content_length then
        print "Setting state to 7"
        reply.state = 7
    end if
    return reply.state = 7
End Function

Function debug_buffer(info as String, buffer as Object, offset as Integer)
    dbg = ""
    For i = 0 to 20
        dbg = dbg + chr(buffer[offset + i])
    end For
    print info ; " ( " ; dbg ; " ) "
End Function