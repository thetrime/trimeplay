Function send_event(key as String, value as String)
    bytes = createobject("roByteArray")
    data = list_concat_with_newlines(["<?xml version=" + chr(34) + "1.0" + chr(34) + " encoding=" + chr(34) + "UTF-8" + chr(34) + "?>",
                                      "<!DOCTYPE plist PUBLIC " + chr(34) + "-//Apple//DTD PLIST 1.0//EN" + chr(34) + " " + chr(34) + "http://www.apple.com/DTDs/PropertyList-1.0.dtd" + chr(34) + ">",
                                      "<plist version=" + chr(34) + "1.0" + chr(34) + ">",
                                      " <dict>",
                                      "  <key>category</key>",
                                      "  <string>video</string>",
                                      "  <key>"+key+"</key>",
                                      "  <string>"+value+"</string>",
                                      " </dict>",
                                      "</plist>"])
    packet = "POST /event HTTP/1.1" + chr(13) + chr(10)
    packet = packet + "Content-Type: text/x-apple-plist+xml" + chr(13) + chr(10)
    packet = packet + "Content-Length: " +str(Len(data)) + chr(13) + chr(10)
    packet = packet + chr(13) + chr(10) + data
    print packet ; " ----> " ; m.reverse_connection.getID()
    bytes.fromAsciiString(packet)
    m.reverse_connection.send(bytes, 0, bytes.Count())
End Function

Function read_http_reply(reply as Object, connection as Object)
    length = connection.getCountRcvBuf()
    if length = 0 then
         print "Unexpected EOF"
         GetGlobalAA().connections[Stri(connection.getID())] = invalid
         GetGlobalAA().sockets[Stri(connection.getID())] = invalid
         connection.close()
         return false
    End If
    If reply.state < 6 or reply.body_handler <> invalid then
        reply.buffer.Clear() ' Wow. The socket interface just keeps getting worse!
        reply.buffer[length-1] = 0
        reply.buffer[length-1] = invalid
        r = connection.receive(reply.buffer, 0, length)
        if r <> length then
            print "Read " ; r ; " instead of " ; length
            stop
        end if
    Else        
        reply.body[reply.content_length-1] = 0
        reply.body[reply.content_length-1] = invalid
        r = connection.receive(reply.body, reply.body_size, length)
        reply.body_size = reply.body_size + length
    End If
    if reply.state = 0 then
        parse_http_status(connection, reply)
    else if reply.state = 1 then
        parse_http_headers(connection, reply)
    else if reply.state = 6 Then
        parse_http_body(connection, reply)
    end if
    'print "Reading http reply.... " ; reply.state ; "(length was " ; length ; ")"
    return reply.state = 7
End Function

Function parse_http_status(connection as Object, reply as Object)  
     print "Parsing message on " ; connection.getId()
     While reply.buffer.Count() > 0
        code = reply.buffer.Shift()
        if code = 10 then
            line = reply.status_bytes.toAsciiString()
            reply.status = mid(line, 10, 3)
            print "Status is:" ; reply.status
            reply.state = 4
            reply.headerName = createobject("roByteArray")
            parse_http_headers(connection, reply)
        else if code <> 13 then
            reply.status_bytes.Push(code)
        End if

    End While
End Function

Function handle_http_reverse(reply as Object, connection as Object)
    ' Just ignore them.
    ' But create a new reply object so that we can handle the next message correctly    
    print "Got reverse reply on " ; connection.getId()
    GetGlobalAA().connections[Stri(connection.getId())] = create_new_reply()
    return false
End Function

Function create_new_reply()
    return { state: 0
           headers: {}            
         read_data: read_http_reply
      process_data: handle_http_reverse
         body_size: 0
         
      status_bytes: createobject("roByteArray")
            buffer: createobject("roByteArray")
              body: createobject("roByteArray") }
End Function