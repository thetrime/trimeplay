Sub RunScreenSaver()
    print "Hi, I am a screensaver"
    print m.mac
    while m.state = "photo"
        ' Wait for 2s, then check again
        print "Photos being displayed. Blocking screensaver...."
        msg = wait(2000,p)
    end while
    ' Exit the custom screensaver, triggering the real one!
End Sub