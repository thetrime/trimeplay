PROJECT=$(shell pwd | sed -e 's@.*/@@g')

all: $(PROJECT).zip

SOURCES=source/*.brs

$(PROJECT).zip:	$(SOURCES)
	zip -ru $(PROJECT).zip source manifest -x \*~

install:	$(PROJECT).zip
	curl -s -S -F "mysubmit=Install" -F "archive=@$(PROJECT).zip" -F "passwd=" http://$(ROKU_DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//" | sed "s[</font>[["
