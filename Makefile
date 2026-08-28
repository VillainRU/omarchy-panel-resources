.PHONY: check

check:
	jq -e . manifest.json >/dev/null
	bash -n bin/panel-resources-collect
	node tests/model.test.js
	PANEL_RESOURCES_LANG=en bin/panel-resources-collect | jq -e '.language == "en" and ([.metrics[].label] | index("CPU load") != null)' >/dev/null
	PANEL_RESOURCES_LANG=ru bin/panel-resources-collect | jq -e '.language == "ru" and ([.metrics[].label] | index("Загрузка процессора") != null)' >/dev/null
	qmllint BarWidget.qml Panel.qml
	omarchy plugin validate .
