Function handle_proxy(http as Object, connection as Object)
    ' Ok. First, get a handle to the original connection
    real_url = parse_url(http.search["original_url"])
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

Function read_proxy_reply(reply as Object, connection as Object)
    length = connection.getCountRcvBuf()
    if length = 0 then
         print "Unexpected EOF"
         GetGlobalAA().connections[Stri(connection.getID())] = invalid
         GetGlobalAA().sockets[Stri(connection.getID())] = invalid
         connection.close()
         return false
    End If
    reply.buffer[length-1] = 0
    reply.buffer[length-1] = invalid
    r = connection.receive(reply.buffer, 0, length)
    if reply.state = 6 then
        reply.body_size = reply.body_size + length
    end if
    if reply.state = 0 then
        parse_http_status(connection, reply)
    else if reply.state = 1 then
        parse_http_headers(connection, reply)
    end if
    if reply.state > 5 Then        
        ' We have to ship this to the slave connection. First, anything in the reply.body, then everything in reply.buffer
        if reply.body.count() <> 0 then
            ' FIXME: May not succeed
            reply.slave.send(reply.body, 0, reply.body.count())
        end if
        ' FIXME: May not succeed
        reply.slave.send(reply.buffer, 0, reply.buffer.count())
        if reply.body_size >= reply.content_length then
            reply.state = 7
        end if
    end if
    'print "Reading http reply.... " ; reply.state ; "(length was " ; length ; ")"
    return reply.state = 7
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
    end if
    return false
End Function

Function proxy_data(reply as Object, connection as Object)
    ' reply.buffer contains some data. If we are finished proxying, set reply.state to 7.
    if reply.proxy_state = 0 then
        ' Send headers
        reply.slave.sendStr("HTTP/1.1 200 OK" + chr(13) + chr(10))
        for each header in reply.headers
            reply.slave.sendStr(header + ": " + reply.headers[header] + chr(13) + chr(10))
        end for
        reply.slave.sendStr(chr(13) + chr(10))
        reply.proxy_state = 1
    end if
    ' Send any unsent data
    'print "Read " ; reply.buffer.Count() ; " / " ; reply.content_length ; " bytes from the source"
    while reply.unsent_buffers.count() > 0 and reply.slave.isWritable()
        'print "There are " ; reply.unsent_buffers.count(); " unsent buffers"
        buffer = reply.unsent_buffers[0].buffer
        length = reply.unsent_buffers[0].buffer.count() - reply.unsent_buffers[0].from
        print "-------------------------Case 1 at " ; reply.sent
        'debug_buffer("case 2", buffer, reply.unsent_buffers[0].from)
        sent = reply.slave.send(buffer, reply.unsent_buffers[0].from, length)        
        'print "----------> " ; sent
        if sent = length then
           reply.sent = reply.sent + sent
           reply.unsent_buffers.shift()
        else if sent = -1 then      
            if reply.slave.eWouldBlock() ' Makes me wonder just what isWritable does?
                ' We still have to save the current buffer or we will lose it
                backing_buffer = createobject("roByteArray")
                backing_buffer.append(reply.buffer)
                'print "Adding new unsent buffer, starting from zero"
                reply.unsent_buffers.push({buffer: backing_buffer,
                                             from: 0})
                reply.slave.notifyWritable(true)
                return false ' We just have to try again later
            end if            
            print reply.slave.status()
            print reply.slave.eOK()
            print reply.slave.eWouldBlock()
            print reply.slave.eSuccess()
            stop
        else
            reply.unsent_buffers[0].from = reply.unsent_buffers[0].from + sent
            reply.sent = reply.sent + sent
            reply.slave.notifyWritable(true)
           return false
        end if        
    end while
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