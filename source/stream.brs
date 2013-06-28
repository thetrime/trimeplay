Function HttpStream(connection as Object) 
    return {          get_code: get_code_from_buffer
                     peek_code: peek_code_from_buffer
                     read_line: get_line_from_buffer
                  read_n_bytes: read_n_bytes_from_buffer

                          fill: fill_buffer
                        buffer: []
                    connection: connection }
End Function

Function get_code_from_buffer()
    If m.buffer.Count() > 0
       return m.buffer.Shift()
    End If
    m.buffer = createobject("roByteArray")
    m.fill(m.buffer, 0, m.connection.getCountRcvBuf())
    return m.get_code()
End Function

Function read_n_bytes_from_buffer(n as Integer)
    bytes = createobject("roByteArray")
    r = m.buffer.count() - 1
    ' First we must drain the buffer. This is slow because there is no array copy in brightscript :(
    if (r > n)
       r = n
    end if
    For i = 1 to r step 1
        bytes.push(m.buffer.Shift())
    End For
    
    ' now we can read quickly by calling receive()
    m.fill(bytes, r, n-r)
    return bytes
End Function


Function peek_code_from_buffer()
    If m.buffer.Count() > 0
       return m.buffer[0]
    End If
    m.fill(m.buffer, 0, m.connection.getCountRcvBuf())
    return m.peek_code()
End Function

Function wait_for_data(connection as Object)
     z = connection.getMessagePort()
     print "Waiting for more data on " ; connection.getID()
     event = wait(0, z)
     print "Got data on " ; event.getSocketID()
End Function


Function fill_buffer(buffer as Object, start as integer, length as integer)
    buffer[length] = 0
    buffer[length] = invalid
    if length = 0 then
        wait_for_data(m.connection)
    End If
    While start < length
        If m.connection.isReadable()
            bytes_read = m.connection.receive(buffer, start, length-start)
            if bytes_read < 0
                if m.connection.eAgain()
                    wait_for_data(m.connection)
                Else
                    stop
                end if
            Else
                start = start + bytes_read
            End if
        End If
    end While    
End Function

Function get_line_from_buffer()
    line = ""
    While true
        code = m.get_code()
        if code = -1
           stop
        else if code = 13
           m.get_code() ' Skip 10
           return line
        end if
        line = line + chr(code)
    End While
End Function
