Function handle_reverse(http as Object, connection as Object)
    reply = createobject("roByteArray")
    reply.fromAsciiString("HTTP/1.1 101 Switching Protocols" + chr(13) + chr(10) + "Date: Thu, 23 Feb 2012 17:33:41 GMT" + chr(13) + chr(10) + "Upgrade: PTTH/1.0" + chr(13) + chr(10) + "Connection: Upgrade" + chr(13) + chr(10) + chr(13) + chr(10))
    status = connection.send(reply, 0, reply.Count())
    print "Reversal: " ; connection.getID()
    m.reversals[Stri(connection.getID())] = connection
    return status
End Function

Function handle_server_info(http as Object, connection as Object)
    ' Really? You cannot escape quotes?!
    device_id = "<string>" + m.mac + "</string>"
    features = "  <integer>" + m.features + "</integer>"

    return send_http_reply(connection, "text/x-apple-plist+xml", list_concat_with_newlines(["<?xml version=" + chr(34) + "1.0" + chr(34) + " encoding=" + chr(34) + "UTF-8" + chr(34) + "?>",
                                                                                            "<!DOCTYPE plist PUBLIC " + chr(34) + "-//Apple//DTD PLIST 1.0//EN" + chr(34) + " " + chr(34) + "http://www.apple.com/DTDs/PropertyList-1.0.dtd" + chr(34) + ">",
                                                                                            "<plist version=" + chr(34) + "1.0" + chr(34) + ">",
                                                                                            " <dict>",
                                                                                            "  <key>deviceid</key>",
                                                                                            device_id
                                                                                            "  <key>features</key>",
                                                                                            "  <key>model</key>",
                                                                                            "  <string>AppleTV2,1</string>",
                                                                                            "  <key>protovers</key>",
                                                                                            "  <string>1.0</string>",
                                                                                            "  <key>srcvers</key>",
                                                                                            "  <string>120.2</string>",
                                                                                            " </dict>",
                                                                                            "</plist>"]))
End Function


Function handle_slideshow_features(http as Object, connection as Object)
    ' Really? You cannot escape quotes?!
    return send_http_reply(connection, "text/x-apple-plist+xml", list_concat_with_newlines(["<?xml version=" + chr(34) + "1.0" + chr(34) + " encoding=" + chr(34) + "UTF-8" + chr(34) + "?>",
                                                                                            "<!DOCTYPE plist PUBLIC " + chr(34) + "-//Apple//DTD PLIST 1.0//EN" + chr(34) + " " + chr(34) + "http://www.apple.com/DTDs/PropertyList-1.0.dtd" + chr(34) + ">",
                                                                                            "<plist version=" + chr(34) + "1.0" + chr(34) + ">",
                                                                                            " <dict>",
                                                                                            "  <key>themes</key>",
                                                                                            "  <array>",
                                                                                            "    <dict>",
                                                                                            "      <key>key</key>",
                                                                                            "      <string>Reflections</string>",
                                                                                            "    </dict>",
                                                                                            "  </array>",
                                                                                            " </dict>",
                                                                                            "</plist>"]))
End Function

Function handle_stream(http as Object, connection as Object)
    ' Really? You cannot escape quotes?!
    return send_http_reply(connection, "text/x-apple-plist+xml", list_concat_with_newlines(["<?xml version=" + chr(34) + "1.0" + chr(34) + " encoding=" + chr(34) + "UTF-8" + chr(34) + "?>",
                                                                                            "<!DOCTYPE plist PUBLIC " + chr(34) + "-//Apple//DTD PLIST 1.0//EN" + chr(34) + " " + chr(34) + "http://www.apple.com/DTDs/PropertyList-1.0.dtd" + chr(34) + ">",
                                                                                            "<plist version=" + chr(34) + "1.0" + chr(34) + ">",
                                                                                            " <dict>",
                                                                                            "   <key>height</key>",
                                                                                            "   <integer>720</integer>",
                                                                                            "   <key>overscanned</key>",
                                                                                            "   <true/>",
                                                                                            "   <key>refreshRate</key>",
                                                                                            "   <real>0.016666666666666666</real>",
                                                                                            "   <key>version</key>",
                                                                                            "   <string>130.14</string>",
                                                                                            "   <key>width</key>",
                                                                                            "   <integer>1280</integer>",
                                                                                            " </dict>",
                                                                                            "</plist>"]))
End Function


Function handle_photo(http as Object, connection as Object)
    print "About to save data to file..." ; str(http.body.Count())
    print http.body.WriteFile("tmp:/myphoto1.jpg")
    bitmap = CreateObject("roBitmap", "tmp:/myphoto1.jpg")
    print "About to draw image: " ; bitmap
    m.screen.clear(0)
    x_offset = (m.screen.GetWidth() - bitmap.GetWidth())/2
    y_offset = (m.screen.GetHeight() - bitmap.GetHeight())/2
    m.screen.DrawObject(x_offset, y_offset, bitmap)
    m.screen.SwapBuffers()   
    return send_http_reply(connection, "text/x-apple-plist+xml", "")
End Function

Function handle_stop(http as Object, connection as Object)
    return send_http_reply(connection, "text/x-apple-plist+xml", "")
End Function

Function handle_play(http as Object, connection as Object)
    params = {}
    name = createobject("roByteArray")
    state = 0
    if http.headers["content-type"] = "application/x-apple-binary-plist"
        ' Blast.
        params = parse_bplist(http.body)
    Else
        For Each byte in http.body
            print byte
            If byte = 58 and state = 0 Then
                value = createobject("roByteArray")
                state = 2
            Else if byte = 10 and state = 1 Then
               ' End of record
               params[Lcase(name.toAsciiString())] = value.toAsciiString()
               print "Got:"; Lcase(name.toAsciiString()) ; "=" ; value.toAsciiString()
               name = createobject("roByteArray")
               state = 0
            Else if state = 2 and byte <> 32 Then
               state = 1
               value.push(byte)
            Else If state = 0 Then
               name.push(byte)
            Else If state = 1 Then
               value.push(byte)
            End If
        End For
    End If
    If params["content-location"] <> invalid Then
       content = {}
       content.Stream = { url:params["content-location"]
                      quality:false
                    contentid:"airplay-content"}
       content.StreamFormat = "mp4"
       m.screen.setContent(content)
       m.screen.show()
       print "Here goes!"
    End If


    return send_http_reply(connection, "text/x-apple-plist+xml", "")
End Function


Function list_concat_with_newlines(chunks as Object)
    output = ""
    For Each chunk in chunks
        output = output + chunk + chr(13)
    End For
    return output
End Function

Function send_http_reply(connection as Object, content_type as String, data as String)
    reply = createobject("roByteArray")
    packet = "HTTP/1.1 200 OK" + chr(13) + chr(10)
    packet = packet + "Date: Thu, 23 Feb 2012 17:33:41 GMT" + chr(13) + chr(10)
    packet = packet + "Content-Type: " + content_type + chr(13) + chr(10)
    packet = packet + "Content-Length: " + str(len(data)) + chr(13) + chr(10) + chr(13) + chr(10)
    packet = packet + data
    reply.fromAsciiString(packet)
    status = connection.send(reply, 0, reply.Count())
    return status
End Function

Function dispatch_http(http as Object, connection as Object)
    print "Handling " ; http.path
    If http.path = "/reverse" Then
        status = handle_reverse(http, connection)
    Else If http.path = "/server-info" Then
        status = handle_server_info(http, connection)
    Else If http.path = "/slideshow-features" Then
        status = handle_slideshow_features(http, connection)
    Else If http.path = "/photo" Then
        status = handle_photo(http, connection)
    Else If http.path = "/stop" Then
        status = handle_stop(http, connection)
    Else If http.path = "/play" Then
        status = handle_play(http, connection)
    Else If http.path = "/stream.xml" Then
        status = handle_stream(http, connection)
    Else
        print "Unexpected URI: "; http.path
    End If
    print "Status: " ; status
End Function