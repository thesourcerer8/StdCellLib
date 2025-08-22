VOLARE_REVISION=ddb601a4a4473163e1ed6df416b885df18b4ac03
BASE_PATH=${PDK_ROOT}/volare/ihp_sg13g2/versions/${VOLARE_REVISION}/ihp-sg13g2

libresilicon.tech: ${BASE_PATH}/libs.tech/magic/ihp-sg13g2.tech
	perl ../Tools/perl/drcexpander.pl ${BASE_PATH}/libs.tech/magic/ihp-sg13g2.tech > libresilicon.tech

#design.ngspice: ${BASE_PATH}/libs.tech/ngspice/parameters/invariant.spice
design.ngspice:
	python ../Tools/python/create_design_spice.py ${BASE_PATH}/libs.tech/ngspice/models

transistors.ngspice: ${BASE_PATH}/libs.tech/ngspice/models/cornerMOSlv.lib
	python ../Tools/python/expandSICElib.py mos_fs ${BASE_PATH}/libs.tech/ngspice/models/cornerMOSlv.lib transistors.ngspice

all: libresilicon.tech design.ngspice transistors.ngspice
