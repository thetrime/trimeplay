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
    print packet
    bytes.fromAsciiString(packet)
    m.current_connection.send(bytes, 0, bytes.Count())
End Function

Function read_http_reply(connection as Object, reply as Object)
    length = connection.getCountRcvBuf()
    If reply.state < 6 Then
        reply.buffer[length-1] = 0
        reply.buffer[length-1] = invalid
        r = connection.receive(reply.buffer, 0, length)
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
    return reply.state = 7
End Function

Function parse_http_status(connection as Object, reply as Object)
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

Function create_new_reply()
    return { state: 0
           headers: {}            
         body_size: 0
         
      status_bytes: createobject("roByteArray")
            buffer: createobject("roByteArray")
              body: createobject("roByteArray") }
End Function