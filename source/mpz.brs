' This module contains some functions to do multi-precision integer arithmetic.
' I really miss Prolog :(

' Add two numbers
Function add_strings(a as String, b as String)
    carry = 0
    ' we want A to be longer than B. If B is longer than A, swap them
    aa = createobject("roByteArray")
    bb = createobject("roByteArray")
    c = createobject("roByteArray")
    if len(b) > len(a) then
        aa.fromAsciiString(b)
        bb.fromAsciiString(a)
    else
        aa.fromAsciiString(a)
        bb.fromAsciiString(b)
    End If    
    While aa.count() > 0
        aaa = aa.pop() - 48
        if bb.count() > 0 then
            bbb = bb.pop() - 48
        else
            bbb = 0
        end if
        sum = aaa + bbb + carry
        carry = int(sum / 10)
        sum = sum MOD 10
        c.UnShift(sum + 48)
    End While
    if carry <> 0 then
        c.UnShift(carry + 48)
    end if
    ' trim leading zeroes
    while c[0] = 48
        c.shift()
    end while
    return c.toAsciiString()
End Function

' Multiply two numbers
Function multiply_string(a as String, b as String)
    carry = 0
    ' we want A to be longer than B. If B is longer than A, swap them
    aa = createobject("roByteArray")
    bb = createobject("roByteArray")
    products = []
    if len(b) > len(a) then
        aa.fromAsciiString(b)
        bb.fromAsciiString(a)
    else
        aa.fromAsciiString(a)
        bb.fromAsciiString(b)
    End If
    i = 0
    For k = bb.count()-1 to 0 step - 1
       c = createobject("roByteArray")
       bbb = bb[k] - 48
       For j = 1 to i step 1
          ' Put i 0s into the product
          c.UnShift(48)
       End For
       ' Muliply all of aa by bbb
       For j = aa.count()-1 to 0 step -1
          aaa = aa[j] - 48
          product = aaa * bbb + carry
          carry = int(product / 10)
          c.UnShift((product MOD 10) + 48)
       End For
       if carry <> 0 then
           c.UnShift(carry+48)
       end if
       products.push(c.toAsciiString())
       i = i + 1
       carry = 0
    End For
    ' Now sum them all up
    result = "0"
    For each product in products
        result = add_strings(result, product)
    End For
    return result
End Function

' Add subtract numbers
Function subtract_strings(a as String, b as String)
    carry = 0
    ' Assumption is that A > B
    aa = createobject("roByteArray")
    bb = createobject("roByteArray")
    c = createobject("roByteArray")
    aa.fromAsciiString(a)
    bb.fromAsciiString(b)
    While aa.count() > 0
        aaa = aa.pop() - 48
        if bb.count() > 0 then
            bbb = bb.pop() - 48
        else
            bbb = 0
        end if
        difference = aaa - bbb - carry
        if difference < 0 then
            carry = 1
            difference = difference + 10
        else
            carry = 0
        end if
        c.UnShift(difference + 48)
    End While
    ' The carry really should be 0 here or A < B
    ' trim leading zeroes
    while c[0] = 48
        c.shift()
    end while
    return c.toAsciiString()
End Function

' This is for importing a number from an N-byte hex value into a string
Function add_byte(a as String, b as Integer)
    f = multiply_string(a, "256")
    return add_strings(f, b.toStr())
End Function 