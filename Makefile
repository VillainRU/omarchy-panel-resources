.PHONY: check

check:
	jq -e . manifest.json >/dev/null
	bash -n bin/panel-resources-collect
	node tests/model.test.js
	bash tests/security.test.sh
	PANEL_RESOURCES_LANG=en bin/panel-resources-collect | jq -e '.language == "en" and ([.metrics[].label] | index("CPU load") != null)' >/dev/null
	PANEL_RESOURCES_LANG=ru bin/panel-resources-collect | jq -e '.language == "ru" and ([.metrics[].label] | index("Загрузка процессора") != null)' >/dev/null
	PANEL_RESOURCES_LANG=en bin/panel-resources-collect | jq -e '(.metrics | length) <= 16 and ([.metrics[] | (.id | length) <= 48 and (.label | length) <= 64 and (.shortLabel | length) <= 12 and (.value | length) <= 16 and (.detail | length) <= 96] | all)' >/dev/null
	test "$$(PANEL_RESOURCES_LANG=en bin/panel-resources-collect | wc -c)" -le 8193
	! rg -q 'StdioCollector' Panel.qml
	rg -q 'command: \["/usr/bin/timeout"' Panel.qml
	qmllint BarWidget.qml Panel.qml
	omarchy plugin validate .
