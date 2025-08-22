BASE_PATH=${PDK_ROOT}/volare/sky130/versions/${VOLARE_REVISION}/sky130A

libresilicon.tech: ${BASE_PATH}/libs.tech/magic/sky130A.tech
	perl ../Tools/perl/drcexpander.pl ${BASE_PATH}/libs.tech/magic/sky130A.tech | grep -v "lambda  1E6" > libresilicon.tech

design.ngspice: ${BASE_PATH}/libs.tech/ngspice/parameters/invariant.spice
	cp ${BASE_PATH}/libs.tech/ngspice/parameters/invariant.spice design.ngspice

transistors.ngspice: ${BASE_PATH}/libs.tech/ngspice/sky130.lib.spice
	python ../Tools/python/expandSICElib.py tt ${BASE_PATH}/libs.tech/ngspice/sky130.lib.spice transistors.ngspice

all: libresilicon.tech design.ngspice transistors.ngspice
