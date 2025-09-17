After updating the magic .tech file (libresilicon.tech), the following line needs to be commented out to disable this DRC rule:

# area allm2,obsm2 144000 200 "Metal2 minimum area < %a (M2.d)" # THIS RULE CANNOT BE FULFILLED
 BY STANDARD CELLS

