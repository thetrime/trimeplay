Function handle_proxy(http as Object, connection as Object)
    print http.headers
    ' Ok. First, get a handle to the original connection
    real_url = parse_url(http.search["original_url"])
    delta = http.search["delta"]
    if delta = invalid then
       delta = "0"
    end if
    edit_from = http.search["edit_from"]
    edit_source = http.search["edit_source"]
    edit_length = http.search["edit_length"]
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
    reply.edits = []
    if edit_from <> invalid then
        buffer = createobject("roByteArray")
        buffer.ReadFile(edit_source)
        print "Read " ; buffer.count() ; " bytes from " ; edit_source
        reply.edits.push({edit_start: val(edit_from)
                       delete_length: val(edit_length)
                      replace_length: buffer.count()
                                 ptr: 0
                              buffer: buffer})
    end if
    print "Edits: " ; reply.edits
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
        reply.edits = request.edits
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
    print "-------------------------Flushing at " ; source.sent
    While source.unsent_buffers.count() > 0 and connection.isWritable()
        buffer = source.unsent_buffers[0].buffer
        length = source.unsent_buffers[0].buffer.count() - source.unsent_buffers[0].from
        'debug_buffer("case 1", buffer, source.unsent_buffers[0].from)
        print "Flushing buffer from " ; source.unsent_buffers[0].from ; " of length " ; length
        sent = forward_data(connection, buffer, source.unsent_buffers[0].from, length, source)
        'sent = connection.send(buffer, source.unsent_buffers[0].from, length)
        if sent = length then
           source.sent = source.sent + sent
           source.unsent_buffers.shift()
        else if sent = -1 then      
            if connection.eWouldBlock()
                return false ' We just have to try again later
            else if connection.eConnReset() then
                ' They hung up on us
                return true
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
        ' FIXME: Could also set the other socket to notifyReadable(false) if there are too many buffers to slow down
        connection.notifyWritable(true)
    end if
    return false
End Function

Function proxy_data(reply as Object, connection as Object)
    print "in proxy_data"
    debug_buffer("enter_proxy_data", reply.buffer, 0)
    ' reply.buffer contains some data. If we are finished proxying, set reply.state to 7.
    if reply.proxy_state = 0 then
        ' Send headers
        reply.slave.sendStr("HTTP/1.1 200 OK" + chr(13) + chr(10))
        for each header in reply.headers
            if reply.delta <> "0" and header = "content-length" Then
                reply.slave.sendStr(header + ": " + add_strings(reply.delta, reply.headers[header]) + chr(13) + chr(10))
                print "new content-length: " ; add_strings(reply.delta, reply.headers[header]) ; " from " ; reply.headers[header]
            else
                reply.slave.sendStr(header + ": " + reply.headers[header] + chr(13) + chr(10))
            end if
        end for
        reply.slave.sendStr(chr(13) + chr(10))
        reply.proxy_state = 1
    end if
    flush_proxy({source:reply}, reply.slave)
    if reply.buffer.count() > 0 then
        print "Buffer contains " ; reply.buffer.count() ; " bytes"     
        ' ONLY send data if there are no unsent queued buffers!
        if reply.slave.isWritable() and reply.unsent_buffers.count() = 0 then
            'print "-------------------------Case 2 at " ; reply.sent
            'debug_buffer("case 3", reply.buffer, 0)
            'sent = reply.slave.send(reply.buffer, 0, reply.buffer.count())
            print "Sending data directly from reply buffer"
            debug_buffer("Direct data", reply.buffer, 0)
            sent = forward_data(reply.slave, reply.buffer, 0, reply.buffer.count(), reply)
            print sent
        else
            sent = 0
        end if
        if sent = -1 and reply.slave.eWouldBlock() then
            sent = 0
        else if sent = -1 and reply.slave.eConnReset() then            
            return true
        else if sent = -1 then
            print connection.status()
            print connection.eOK()
            print connection.eWouldBlock()
            print connection.eSuccess()
            stop
        end if
        reply.sent = reply.sent + sent
        if sent < reply.buffer.count() then
            print "Only sent " ; sent ; " bytes out of " ; reply.buffer.count()
            reply.slave.notifyWritable(true)
            ' Save some for later. Who knows how incredibly inefficient this is?
            backing_buffer = createobject("roByteArray")
            backing_buffer.append(reply.buffer)
            print "Adding new unsent buffer, starting from " ; sent
            debug_buffer("Unsent buffer", backing_buffer, sent)
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
    print "Exiting proxy_data"
    return reply.state = 7
End Function

Function debug_buffer(info as String, buffer as Object, offset as Integer)
    return 0

    dbg = ""
    For i = 0 to buffer.count() - offset - 1
        dbg = dbg + chr(buffer[offset + i])
    end For
    print info ; " ( " ; dbg ; " ) "
End Function

Function forward_data(socket as Object, buffer as Object, offset as Integer, length as Integer, source as Object)
    if source.edits.count() <> 0 and source.sent + length > source.edits[0].edit_start then
        ' First, do we need to send SOME of the real buffer?
        if source.sent < source.edits[0].edit_start then
            print "Need to copy some real data: " ; source.edits[0].edit_start - source.sent
            x = forward_data(socket, buffer, offset, source.edits[0].edit_start - source.sent, source)
            print "Returning " ; x
            return x
        end if
        skipped = 0
        print "Discarding bytes"
        ' Discard bytes rather than sending them
        while length > 0 and source.edits[0].delete_length > 0
            offset = offset + 1
            length = length - 1
            source.edits[0].delete_length = source.edits[0].delete_length - 1
            skipped = skipped + 1
        end while
        ' At this point, we have two possibilities:
        ' 1) We have successfully ignored the entire original payload, and should be injecting some of the new payload
        ' 2) We have not yet received the entire original payload
        if source.edits[0].delete_length = 0 then
            ' Case 1
            print "Ready to inject!"        
            s = socket.send(source.edits[0].buffer, source.edits[0].ptr, source.edits[0].replace_length)
            if s > 0 then
                ' We sent some/all of the buffer. Update the pointer and reduce the length
                source.edits[0].ptr = source.edits[0].ptr + s
                source.edits[0].replace_length = source.edits[0].replace_length - s                
            end if
            ' Have we finished? 
            if source.edits[0].replace_length = 0 then
                ' Yes, so dequeue this edit
                print "Finished edit"
                source.edits.shift()
            end if
            print "Returning " ; skipped
            return skipped
        else
            ' Case 2. We have not actually transmitted anything, but it is not an error. However, for the purposes of the reading
            ' socket, we *seem* to have transferred some bytes which we actually skipped
            print "Not yet discarded enough"
            return skipped
        end if
    end if
    print "Copying raw stream"
    debug_buffer("foo", buffer, offset)
    z =  socket.send(buffer, offset, length)
    print z ; " bytes of raw stream copied out of a possible " ; length
    return z
End Function
