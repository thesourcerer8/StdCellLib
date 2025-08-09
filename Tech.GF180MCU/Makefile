BASE_PATH=${PDK_ROOT}/volare/gf180mcu/versions/${VOLARE_REVISION}/gf180mcuD

libresilicon.tech: ${BASE_PATH}/libs.tech/magic/gf180mcuD.tech
	perl ../Tools/perl/drcexpander.pl ${BASE_PATH}/libs.tech/magic/gf180mcuD.tech >libresilicon.tech

design.ngspice: ${BASE_PATH}/libs.tech/ngspice/design.ngspice
	cp ${BASE_PATH}/libs.tech/ngspice/design.ngspice design.ngspice

transistors.ngspice: ${BASE_PATH}/libs.tech/ngspice/sm141064.ngspice
	cp ${BASE_PATH}/libs.tech/ngspice/sm141064.ngspice transistors.ngspice

all: libresilicon.tech design.ngspice transistors.ngspice
