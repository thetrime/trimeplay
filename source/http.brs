Function create_new_request()
    return {  state: 0
            headers: {}
             method: ""
          body_size: 0
          pathBytes: createobject("roByteArray")
             buffer: createobject("roByteArray")
               body: createobject("roByteArray")
           }
End Function

Function read_http(connection as Object, request as Object)
    length = connection.getCountRcvBuf()
    print "Processing message on socket: " ; connection.getID() ; " of length " ; length
    If request.state < 5 Then
        request.buffer[length] = 0
        request.buffer[length] = invalid
        r = connection.receive(request.buffer, 0, length)
    Else        
        request.body[request.content_length] = 0
        request.body[request.content_length] = invalid
        r = connection.receive(request.body, request.body_size, length)
        request.body_size = request.body_size + length
    End If

    ' Great. No switch statements
    If request.state = 0 Then
       parse_request_line(connection, request)
    Else If request.state = 1 Then
       parse_path(connection, request)
    Else If request.state = 2 Then
       parse_http_version(connection, request)
    Else If request.state = 3 Then
       parse_headers(connection, request)
    Else If request.state = 4 Then
       parse_headers(connection, request)
    Else If request.state = 5 Then
       parse_body(connection, request)
    End If
    print "Final state is " ; request.state
    return request.state = 6
End Function


Function parse_body(connection as Object, request as Object)
    While request.buffer.Count() > 0
        request.body.Push(request.buffer.Shift())
        request.body_size = request.body_size + 1
    End While
    if request.body_size >= request.content_length Then
       request.state = 6
    End If
End Function

Function parse_headers(connection as Object, request as Object)
    While request.buffer.Count() > 0 and request.state < 5
        If request.state = 3 Then
           ' From 3, either go to 4 or 5
           parse_header_name(connection, request)
        End If
        If request.state = 4 Then
           ' From 4 always go to 3
           parse_header_value(connection, request)
        End If
    End While
End Function

Function parse_header_name(connection as Object, request as Object)
    While request.buffer.Count() > 0
        code = request.buffer.Shift()
        If code = 13 Then
           ' Do nothing
        Else If code = 10 Then
           ' Must be end of headers
           request.state = 5
           request.content_length = val(request.headers["content-length"])
           parse_body(connection, request)
           Exit While
        Else If code = 58 Then
            ' End of header name
            request.headerValue = createobject("roByteArray")
            ' trim header name
            While request.headerName[0] = 32
                  request.headerName.Shift()
            End While
            While request.headerName.Peek() = 32
                  request.headerName.Pop()
            End While
            request.state = 4
            Exit While
        Else
            request.headerName.Push(code)
        End If        
    End While
End Function

Function parse_header_value(connection as Object, request as Object)
    While request.buffer.Count() > 0
        code = request.buffer.Shift()
        If code = 13 Then
           ' Do nothing
        Else If code = 10 Then
           ' End of header value
           header_name = Lcase(request.headerName.toAsciiString())
            While request.headerValue[0] = 32
                  request.headerValue.Shift()
            End While

           header_value = request.headerValue.toAsciiString()
           request.headers[header_name] = header_value           
           ' Reset header name
           request.headerName = createobject("roByteArray")
           request.state = 3
           Exit While
        Else
           request.headerValue.Push(code)
        End If
    End While
End Function


Function parse_http_version(connection as Object, request as Object)
    While request.buffer.Count() > 0
        code = request.buffer.Shift()
        If code = 10 Then
           request.state = 3
           request.headerName = createobject("roByteArray")
           parse_headers(connection, request)
           Exit While
        End If
    End While
End Function

Function parse_path(connection as Object, request as Object)
    While request.buffer.Count() > 0
        code = request.buffer.Shift()
        If code = 32 Then
           request.path = request.pathBytes.toAsciiString()
           request.state = 2
           parse_http_version(connection, request)
           Exit While
        End If
        request.pathBytes.Push(code)
    End While
End Function

Function parse_request_line(connection as Object, request as Object)
    While request.buffer.Count() > 0
        code = request.buffer.Shift()
        If code = 32 Then
            request.state = 1
            parse_path(connection, request)
            Exit While
        End If
        request.method = request.method + Lcase(str(code))
    End While
End Function



'So, what if we had a central loop that JUST read http requests
'We have a list of (socket,request) pairs. Only once a request has been fully read do we actually dispatch it
'Until then, each time a socket is ready for reading, tell the request-parser to read some more data from the socket
'The request-parser then has to remember exactly what state is was in. There are only a few states:
'1) Request
'2) Path
'3) HTTP version
'4) Header name
'5) Header value
'6) Data
'This might make streaming video difficult, of course :(
