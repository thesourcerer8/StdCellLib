import os
from lclayout.layout.layers import *
from lclayout.writer.magic_writer import MagWriter
from lclayout.writer.lef_writer import LefWriter
from lclayout.writer.gds_writer import GdsWriter
from lclayout.writer.oasis_writer import OasisWriter

# This Tech file was created for 5V transistors for GlobalFoundries GF180MCU. There might be one layer missing for them. We could create additional cells for 3.3V and 6V, but that would change a lot of the DRC rules

db_unit = 1e-3

# Lambda - how many db_units is 1 lambda?
grid = 5 # grid basis
um = 1000
nm = 1

targetvoltage=os.environ.get("TARGETVOLTAGE","3.3V") # "3.3V" "5V" "6V" "10V"  # unfortunately 1.8V does not seem to be available on GF180
# "5V" => Operating Voltage VDD = 1.62 - 5.5V according to https://gf180mcu-pdk.readthedocs.io/en/latest/digital/standard_cells/gf180mcu_fd_sc_mcu7t5v0/spec/electrical.html

tracks=int(os.environ.get("TRACKS","9"))

use_deep_nwell =os.environ.get("DNWELL","True")

print("GF180 standard cell configuration: TARGETVOLTAGE="+targetvoltage+" TRACKS="+str(tracks)+" DNWELL="+use_deep_nwell)

# Scale transistor width.
transistor_channel_width_sizing = 1

# GDS2 layer numbers for final output.
# Keep those definitions always in mind: https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07.html
# GDS2 layers are taken from: https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_04_1.html
# Topological Truthtable for the layers needed in the Standard Cells:
# https://docs.google.com/spreadsheets/d/1WnX2PdoPuBb3nwg5L60u95co2R2abTH1DZLeoyPBLPY/edit#gid=523905120

my_ndiffusion = (22, 0) # warning: ndiffusion+pdiffusion is on the same GDS2 layer, called COMP
my_ndiffusion_label = (22, 0)
my_ndiffusion_pin = (22, 0)
my_pdiffusion = (22, 0) # warning: ndiffusion+pdiffusion is on the same GDS2 layer, called COMP
my_pdiffusion_label = (22, 0)
my_pdiffusion_pin = (22, 0)


my_nwell = (21, 0)
my_nwell_label = (21, 0)
my_nwell_pin = (21, 0)

my_dnwell = (12, 0)

my_pwell = (204, 0) # LVPWELL / Pwell implant

my_dualgate = (55, 0) # Dualgate / 6V Gate Oxide

my_poly = (30, 0) # "Poly2" / POLY2 gate & interconnect /  poly silicium for gates -> poly + ntransistor + ptransistor
my_poly_gate = (30, 0) # poly gates? Why do we have a second layer for gates?
my_poly_label = (30, 0)

my_mcon = (33, 0) # Contact / Metal1 to Active or Poly2 contact
my_metal1 = (34, 0)
my_metal1_label = (34, 0)
my_metal1_pin = (34, 0)
my_via1 = (35, 0) # Metal2 to Metal1 contact
my_metal2 = (36, 0)
my_metal2_label = (36, 0)
my_metal2_pin = (36, 0)
my_via2 = (38, 0) # Metal3 to Metal2 contact
my_metal3 = (42, 0)

my_abutment_box = (63, 0) # Border

my_pplus = (31,0) # P-Plus
my_nplus = (32,0) # N-Plus

my_sab = (49,0) # SAB / Unsalicided poly & active regions


# lclayout internally uses its own layer numbering scheme.
# For the final output the layers can be remapped with a mapping
# defined in this dictioinary.
output_map = {
    l_ndiffusion: my_ndiffusion,
    l_pdiffusion: my_pdiffusion,
    l_nwell: my_nwell, # [my_nwell, my_nwell2],  # Map l_nwell to two output layers.
    l_pwell: my_pwell,  # Output layer for pwell. Uncomment this if needed. For instance for twin-well processes.
    l_poly: my_poly,
    l_poly_contact: my_mcon,
    l_pdiff_contact: my_mcon,
    l_ndiff_contact: my_mcon,
    l_metal1: my_metal1,
    l_metal1_label: my_metal1_label,
    l_metal1_pin: my_metal1_pin,
    l_via1: my_via1,
    l_metal2: my_metal2,
    l_metal2_label: my_metal2_label,
    l_metal2_pin: my_metal2_pin,
    l_abutment_box: my_abutment_box,
    l_pplus: my_pplus,
    l_nplus: my_nplus,
    l_border_vertical: (142, 1),
    l_border_horizontal: (142, 2),
}

# These are only the obstruction layers, only these layers will be generated into the OBS section of the LEF files
obstruction_layers = [
    l_poly_contact,
    l_pdiff_contact,
    l_ndiff_contact,
    l_metal1,
    l_via1,
    l_metal2,
]

output_map_magic = {
            l_nwell: 'nwell',
            l_pwell: 'pwell',
            l_via1: 'via1',
            l_poly: 'poly',
            l_abutment_box: ['abutment'],
            l_metal1: 'met1',
            l_metal2: 'met2',
            l_metal1_label: 'met1',
            l_metal2_label: 'met2',
            l_metal1_pin: 'met1',
            l_metal2_pin: 'met2',
            l_ndiffusion: 'ndiffusion',
            l_pdiffusion: 'pdiffusion',
            l_poly_contact: 'polycont',
            l_pdiff_contact: 'pdiffc',
            l_ndiff_contact: 'ndiffc',
            #l_nplus: 'nplus_s',
            #l_pplus: 'pplus_s'
}


# Define a list of output writers.
output_writers = [
    MagWriter(
        tech_name='gf180mcuD',
        scale_factor=0.2, # Scale all coordinates by this factor (rounded down to next integer).
        output_map=output_map_magic,
        magscale=[1,10]
    ),

    LefWriter(
        db_unit=1e-6, # LEF Fileformat always needs Microns
        obstruction_layers=obstruction_layers,
        output_map=output_map_magic,  # Not supported yet but will be soon
        use_rectangles_only=True,
        site="unit"
    ),

    GdsWriter(
        db_unit=db_unit,
        output_map=output_map
    ),

    OasisWriter(
        db_unit=db_unit,
        output_map=output_map
    )

]

# Define how layers can be used for routing.
# Example for a layer that can be used for horizontal and vertical tracks: {'MyLayer1' : 'hv'}
# Example for a layer that can be contacted but not used for routing: {'MyLayer2' : ''}
routing_layers = {
    l_ndiffusion: '', # Allow adding shapes on diffusion layer but without using it for routing. This is used to automatically add the necessary enclosure around contacts.
    l_pdiffusion: '', # Allow adding shapes on diffusion layer but without using it for routing. This is used to automatically add the necessary enclosure around contacts.
    l_poly: 'v', # We dont want horizontal rouing on poly
    l_metal1: 'hv',
    l_metal2: 'hv',
}

# Minimum spacing rules for layer pairs.
min_spacing = {
    (l_ndiffusion, l_ndiffusion): 280*nm if targetvoltage=='3.3V' else 360*nm, # DF.3a for 5V https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    #(l_ndiffusion, l_outline): 360/2*nm, # DF.3a for 5V https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    (l_pdiffusion, l_ndiffusion): 280*nm if targetvoltage=='3.3V' else 360*nm, # DF.3a for 5V https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    #(l_pdiffusion, l_outline): 360/2*nm, # DF.3a for 5V https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    (l_pdiffusion, l_pdiffusion): 280*nm if targetvoltage=='3.3V' else 360*nm, # DF.3a for 5V https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    (l_ndiffusion, l_poly_contact): 170*nm, # CO.8 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    (l_pdiffusion, l_poly_contact): 170*nm, # CO.8 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    (l_nwell, l_nwell): 600*nm if targetvoltage=='3.3V' else 740*nm, # NW.2a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_05.html
    (l_nwell, l_pwell): 0*nm,   # NW.4 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_05.html
    (l_pwell, l_pwell): 860*nm, # LPW.2b # If it would be the same potential, we could go down to 860*nm according to LPW.2b, if it is different potential we would have to go up to 1.7 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_04.html
    #(l_poly, l_ndiffusion): 300*nm, # PL.5b This is only needed when the poly isn't rectangular, and it doesn't mean the poly that is directly on top of diffusion
    #(l_poly, l_pdiffusion): 300*nm, # PL.5b https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_08.html
    (l_poly, l_poly): 240*nm, # PL.3a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_08.html
    #(l_poly, l_outline): 240/2*nm, # PL.3a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_08.html
    (l_poly, l_pdiff_contact): 150*nm, # CO.7 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    (l_poly, l_ndiff_contact): 150*nm, # CO.7 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    (l_pdiff_contact, l_pdiff_contact): 250*nm, # CO.2a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    #(l_pdiff_contact, l_outline): 270/2*nm, # (difftap.3)
    (l_ndiff_contact, l_ndiff_contact): 250*nm, # CO.2a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    #(l_ndiff_contact, l_outline): 270/2*nm, # (difftap.3)
    (l_pdiff_contact, l_ndiff_contact): 250*nm, # CO.2a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    (l_metal1, l_metal1): 230*nm, # Mn.2a ! This was 250nm?!? DRC rule says 230nm. WARNING: Spacing to huge_met1 (>=10um) needs to be 300nm ! But we most likely wont have huge metal1 inside a standard cell https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_14.html
    #(l_metal1, l_outline): 170/2*nm, # (li.3) # !!!! WARNING: Spacing to huge_met1 (>=?nm) needs to be 280nm !
#    (l_metal1, l_border_vertical): 190*nm, # To move the VIAs at the right place
#    (l_metal2, l_border_vertical): 190*nm, # To move the VIAs at the right place

    (l_metal2, l_metal2): 280*nm, # Mn.2a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_14.html
    # We need metal2 at the border for the power lanes, so we dont put border rules
    (l_via1, l_via1): 260*nm, # Vn.2a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_15.html
    #(l_via1, l_outline): 190/2*nm, # (ct.2)
    #(l_via1, l_diff_contact): 2*l, # NO RULES FOR LICON-MCON spacing found
    #(l_via1, l_ndiffusion): 2*l, # NO RULES FOR MCON-DIFF spacing found
    #(l_via1, l_pdiffusion): 2*l, # NO RULES FOR MCON-DIFF spacing found
    (l_poly_contact, l_pdiff_contact): 250*nm, # CO.2a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    #(l_poly_contact, l_outline): 170/2*nm, # (licon.2)
    (l_poly_contact, l_ndiff_contact): 250*nm, # CO.2a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    (l_ndiffusion, l_pplus): 80*nm, # OR IS IT 160nm??? PP.3 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_10.html
    (l_pdiffusion, l_nplus): 80*nm, # OR IS IT 160nm??? NP.3 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_09.html
    (l_nplus, l_nplus): 400*nm, # NP.2 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_09.html
}

# Layer for the pins.
pin_layer = l_metal2 # lclayout.metal2 = sky130.metal1

# Power stripe layer
power_layer = [l_metal1, l_metal2] # lclayout.metal2 = sky130.metal1

# Layers that can be connected/merged without changing the schematic.
# This can be used to resolve spacing/notch violations by just filling the space.
connectable_layers = {l_pwell, l_poly, l_metal1} # l_nwell
# Width of the polysilicon stripe which forms the gate.
# is reused as the minimum_width for the l_poly layer
gate_length_nmos = 280*nm if targetvoltage=='3.3V' else 500*nm if targetvoltage=='5V' else 550*nm # PL.2 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_08.html
gate_length_pmos = 280*nm if targetvoltage=='3.3V' else 600*nm if targetvoltage=='5V' else 700*nm # PL.2 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_08.html

# Minimum length a polysilicon gate must overlap the silicon.
gate_extension = 220*nm # PL.4 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_08.html

# Minimum distance of active area to upper or lower boundary of the cell. Basically determines the y-offset of the transistors.
transistor_offset_y = 340*nm # !!! This likely needs to be tuned later on # The 150/2*nm might have to be removed

# Standard cell dimensions.
# A 'unit cell' corresponds to the dimensions of the smallest possible cell. Usually an inverter.
# `unit_cell_width` also corresponds to the pitch of the gates because gates are spaced on a regular grid.
unit_cell_width = 2*560*nm # (unit SITE) # measured from gf180mcu_fd_sc_mcu9t5v0__inv_1 -> 1.12 um = 2 Tracks = 2*0.56 nm
unit_cell_height = tracks*560*nm # (unit SITE) # measured from gf180mcu_fd_sc_mcu9t5v0__inv_1 -> 5.04 um = 9 Tracks = 9*0.56 nm

#assert unit_cell_height >= 16*um, "minimum 16um due to pwell width + nwell-pwell spacing"
# due to nwell size and spacing requirements routing_grid_pitch_y * 8 # * 8

# Routing pitch
routing_grid_pitch_x = unit_cell_width // 2 # // 4
routing_grid_pitch_y = 135*nm # unit_cell_height // 8 // 2

# Translate routing grid such that the bottom left grid point is at (grid_offset_x, grid_offset_y)
grid_offset_x = routing_grid_pitch_x
grid_offset_y = 0 # (routing_grid_pitch_y // 2 ) -10

# Width of power rail metal.
power_rail_width = 480*nm # decided by the standard cell library architect - might need to be interoperable to other cells


# Minimum gate widths of transistors, i.e. minimal widths of l_ndiffusion and l_pdiffusion (width of COMP).
# It increases w from the spice netlist, so it must be width from the spice netlist
minimum_gate_width_nfet = 220*nm if targetvoltage=='3.3V' else 300*nm # DF.2 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
minimum_gate_width_pfet = 220*nm if targetvoltage=='3.3V' else 300*nm # DF.2 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html

# Minimum width for pins.
minimum_pin_width = 220*nm 

# Width of routing wires.
wire_width = {
    l_ndiffusion: 220*nm if targetvoltage=='3.3V' else 300*nm, # DF.1a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    l_pdiffusion: 220*nm if targetvoltage=='3.3V' else 300*nm, # DF.1a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    l_poly: 280*nm if targetvoltage=='3.3V' else 390*nm,   # PL.1 -> Magic requires 180nm -> But we want 390nm to avoid notches # Checked it again on 2024-04-23 and yes, 390nm makes sense. https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_08.html
    l_metal1: 230*nm, # Mn.1 voltage independent https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_14.html
    l_metal2: 280*nm, # Mn.1 voltage independent https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_14.html
}

# Width of horizontal routing wires (overwrites `wire_width`).
wire_width_horizontal = {
    l_ndiffusion: 220*nm if targetvoltage=='3.3V' else 300*nm, # DF.1a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    l_pdiffusion: 220*nm if targetvoltage=='3.3V' else 300*nm, # DF.1a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    l_poly: 180*nm if targetvoltage=='3.3V' else 200*nm,  # PL.1 -> Magic requires 180nm -> But we want 390nm to avoid notches # Checked it again on 2024-04-23 and yes, 390nm makes sense. https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_08.html
    l_metal1: 230*nm, # Mn.1 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_14.html
    l_metal2: 280*nm, # Mn.1 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_14.html
}

# Side lengths of vias (square shaped).
via_size = {
    l_poly_contact: 230*nm, # CO.1 requires 220nm + magic extensions 2*CO.6 - so the GDS2 file should be 220nm in the end I guess? https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    l_ndiff_contact: 230*nm, # CO.1 requires 220nm + magic extension 2*CO.6 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    l_pdiff_contact: 230*nm, # CO.1 requires 220nm + magic extension 2*CO.6 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    l_via1: 260*nm, # Vn.1 # Why do we not have an extension here like with poly, ndiff and pdiff? https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_15.html
    #l_via2: 260*nm # Vn.1 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_15.html
}

# Minimum width rules.
minimum_width = {
    l_ndiffusion: 220*nm if targetvoltage=='3.3V' else 300*nm, # DF.1a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html  
    l_pdiffusion: 220*nm if targetvoltage=='3.3V' else 300*nm, # DF.1a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html  
    l_poly: 280*nm if targetvoltage=='3.3V' else 500*nm if targetvoltage=='5V' else 550*nm, # PL.2 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_08.html
    l_metal1: 230*nm, # Mn.1 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_14.html
    l_metal2: 280*nm, # Mn.1 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_14.html
    l_nwell: 860*nm, # NW.1a (covering 3.3V, 5V, 6V) https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_05.html
    l_pwell: 600*nm if targetvoltage=='3.3V' else 740*nm, # LPW.1 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_04.html
    l_nplus: 400*nm # NP.1 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_09.html 
}

# Minimum enclosure rules.
# Syntax: {(outer layer, inner layer): minimum enclosure, ...}
minimum_enclosure = {
    # Via enclosure
    (l_ndiffusion, l_ndiff_contact): 70*nm, # (CO.4) https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    (l_pdiffusion, l_pdiff_contact): 70*nm, # (CO.4) https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    (l_poly, l_poly_contact): 70*nm, # (CO.3) https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    # The minimum is 5nm, but since we want to do the overlap symmetrical to achieve reproducibility, when we use 40nm we evade the rule that we would have to use 60nm on the other side:
    (l_metal1, l_pdiff_contact): 40*nm, # (CO.6) https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    (l_metal1, l_ndiff_contact): 40*nm, # (CO.6) https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    (l_metal1, l_poly_contact): 40*nm, # (CO.6) https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_13.html
    # The minimum is 5nm, but since we want to do the overlap symmetrical to achieve reproducibility, when we use 40nm we evade the rule that we would have to use 60nm on the other side:
    (l_metal1, l_via1): 40*nm, # Vn.3 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_15.html
    (l_metal2, l_via1): 40*nm, # V1.4 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_15.html
    # l_*well must overlap l_*diffusion

### CONTINUE HERE

    (l_nwell, l_pdiffusion): 430*nm if targetvoltage=='3.3V' else 600*nm, # (DF.4c) https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
#    (l_pwell, l_ndiffusion): 430*nm if targetvoltage=='3.3V' else 600*nm, # I CANNOT FIND A RULE FOR THIS OUTSIDE DNWELL https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    (l_nplus, l_ndiff_contact): 230*nm, # NP.5a  Implicitly encodes the size of well taps. https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_09.html
    (l_pplus, l_pdiff_contact): 230*nm, # PP.5a  Implicitly encodes the size of well taps. https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_10.html
    #(l_dnwell, l_pwell): 2500*nm,
}

# Minimum notch rules.
minimum_notch = {
    l_ndiffusion: 280*nm if targetvoltage=='3.3V' else 360*nm, # DF.3a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    l_pdiffusion: 280*nm if targetvoltage=='3.3V' else 360*nm, # DF.3a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    l_poly: 240*nm, # PL.3a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_08.html
    l_metal1: 230*nm, # Mn.2a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_14.html
    l_metal2: 280*nm, # Mn.2a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_14.html
    l_nwell: 600*nm if targetvoltage=='3.3V' else 740*nm, # NW.2a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_05.html
    l_pwell: 860*nm, # LPW.2b https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_04.html
}

# Minimum area rules.
min_area = {
    l_ndiffusion: 0.2025 * um * um, # DF.9 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    l_pdiffusion: 0.2025 * um * um, # DF.9 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_06.html
    l_metal1: 0.1444 * um * um ,# Mn.3 https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_14.html
    #l_metal2: 0.1444 * um * um ,# Mn.3  - We don't need to enforce it here since that will be done by Openlane https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_14.html
    l_nplus: 0.35 * um * um, #NP.8a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_09.html
    l_pplus: 0.35 * um * um, #PP.8a https://gf180mcu-pdk.readthedocs.io/en/latest/physical_verification/design_manual/drm_07_10.html 
}

# ROUTING #

# Cost for changing routing direction (horizontal/vertical).
# This will avoid creating zig-zag routings.
orientation_change_penalty = 100000

# Routing edge weights per data base unit.
weights_horizontal = {
    l_ndiffusion: 6300, # (mohms/square)
    l_pdiffusion: 7000, # (mohms/square)
    l_poly: 6300, # (mohms/square)
    l_metal1: 90, # (mohms/square)
    l_metal2: 90, # (mohms/square)
}
weights_vertical = {
    l_ndiffusion: 6300, # (mohms/square)
    l_pdiffusion: 7000, # (mohms/square)
    l_poly: 6300, # (mohms/square)
    l_metal1: 90, # (mohms/square)
    l_metal2: 90, # (mohms/square)
}

viafactor = 1000

# Via weights.
via_weights = {
    (l_metal1, l_ndiffusion): 6300*viafactor, # LICON
    (l_metal1, l_pdiffusion): 5200*viafactor, # LICON
    (l_metal1, l_poly): 5900*viafactor, # LICON
    (l_metal1, l_metal2): 4500*viafactor, # MCON
    (l_metal1, l_nplus): 6300*viafactor, # Contact to Well Taps, the value doesn't matter
    (l_metal1, l_pplus): 5200*viafactor,

}

# Enable double vias between layers.
multi_via = {
    (l_metal1, l_poly): 1,
    (l_metal1, l_metal2): 1,
}

if( min_spacing[(l_pdiff_contact, l_pdiff_contact)] < min_spacing[(l_pdiffusion,l_pdiffusion)]+2*minimum_enclosure[(l_pdiffusion, l_pdiff_contact)]):
        newmin=min_spacing[(l_pdiffusion,l_pdiffusion)]+2*minimum_enclosure[(l_pdiffusion, l_pdiff_contact)]
        print("Minimum Spacing "+str(min_spacing[(l_pdiff_contact, l_pdiff_contact)])+" for pdiff_contact too small because of pdiffusion, minimum should be "+ str(newmin)+"(="+str(min_spacing[(l_pdiffusion,l_pdiffusion)])+"+2*"+str(minimum_enclosure[(l_pdiffusion, l_pdiff_contact)])+") Fixing minimum_spacing")
        min_spacing[(l_pdiff_contact, l_pdiff_contact)]=newmin

if( min_spacing[(l_ndiff_contact, l_ndiff_contact)] < min_spacing[(l_ndiffusion,l_ndiffusion)]+2*minimum_enclosure[(l_ndiffusion, l_ndiff_contact)]):
        newmin=min_spacing[(l_ndiffusion,l_ndiffusion)]+2*minimum_enclosure[(l_ndiffusion, l_ndiff_contact)]
        print("Minimum Spacing "+str(min_spacing[(l_ndiff_contact, l_ndiff_contact)])+" for ndiff_contact too small because of ndiffusion, minimum should be "+ str(newmin)+"(="+str(min_spacing[(l_ndiffusion,l_ndiffusion)])+"+2*"+str(minimum_enclosure[(l_ndiffusion, l_ndiff_contact)])+") Fixing minimum_spacing")
        min_spacing[(l_ndiff_contact, l_ndiff_contact)]=newmin

#if( min_spacing[(l_pdiff_contact, l_ndiff_contact)] < min_spacing[(l_pdiffusion,l_ndiffusion)]+minimum_enclosure[(l_ndiffusion, l_ndiff_contact)]+minimum_enclosure[(l_pdiffusion, l_pdiff_contact)]):
#        newmin=min_spacing[(l_pdiffusion,l_ndiffusion)]+minimum_enclosure[(l_ndiffusion, l_ndiff_contact)]+minimum_enclosure[(l_pdiffusion, l_pdiff_contact)]
#        print("Minimum Spacing "+str(min_spacing[(l_ndiff_contact, l_ndiff_contact)])+" for pdiff_contact - ndiff_contact too small because of ndiffusion, minimum should be "+ str(newmin)+"(="+str(min_spacing[(l_pdiffusion,l_ndiffusion)])+"+"+str(minimum_enclosure[(l_ndiffusion, l_ndiff_contact)])+"+"+str(minimum_enclosure[(l_pdiffusion, l_pdiff_contact)])+") Fixing minimum_spacing")
#        min_spacing[(l_pdiff_contact, l_ndiff_contact)]=newmin

if((l_poly_contact, l_poly_contact) in min_spacing and  min_spacing[(l_poly_contact, l_poly_contact)] < min_spacing[(l_poly,l_poly)]+2*minimum_enclosure[(l_poly, l_poly_contact)]):
        newmin=min_spacing[(l_poly,l_poly)]+2*minimum_enclosure[(l_poly, l_poly_contact)]
        print("Minimum Spacing "+str(min_spacing[(l_poly_contact, l_poly_contact)])+" for poly_contact too small because of polysilicon, minimum should be "+ str(newmin)+"(="+str(min_spacing[(l_poly,l_poly)])+"+"+str(minimum_enclosure[(l_poly, l_poly_contact)])+"+"+str(minimum_enclosure[(l_poly, l_poly_contact)])+") Fixing minimum_spacing")
        min_spacing[(l_poly_contact, l_poly_contact)]=newmin

if((l_poly_contact, l_poly_contact) in min_spacing and  min_spacing[(l_poly_contact, l_poly_contact)] < min_spacing[(l_metal1,l_metal1)]+2*minimum_enclosure[(l_metal1, l_poly_contact)]):
        newmin=min_spacing[(l_metal1,l_metal1)]+2*minimum_enclosure[(l_metal1, l_poly_contact)]
        print("Minimum Spacing "+str(min_spacing[(l_poly_contact, l_poly_contact)])+" for poly_contact too small because of local interconnect, minimum should be "+ str(newmin)+"(="+str(min_spacing[(l_metal1,l_metal1)])+"+"+str(minimum_enclosure[(l_metal1, l_poly_contact)])+"+"+str(minimum_enclosure[(l_metal1, l_poly_contact)])+") Fixing minimum_spacing")
        min_spacing[(l_poly_contact, l_poly_contact)]=newmin

#if( min_spacing[(l_via1, l_via1)] < min_spacing[(l_metal1,l_metal1)]+2*minimum_enclosure[(l_metal1, l_via1)]):
#	newmin=min_spacing[(l_metal1,l_metal1)]+2*minimum_enclosure[(l_metal1, l_via1)]
#	print("Minimum Spacing "+str(min_spacing[(l_via1, l_via1)])+" for via1 too small because of metal1, minimum should be "+ str(newmin)+"(="+str(min_spacing[(l_metal1,l_metal1)])+"+2*"+str(minimum_enclosure[(l_metal1, l_via1)])+") Fixing minimum_spacing")
#	min_spacing[(l_via1, l_via1)]=newmin

#if( min_spacing[(l_via1, l_via1)] < min_spacing[(l_metal2,l_metal2)]+2*minimum_enclosure[(l_metal2, l_via1)]):
#	newmin=min_spacing[(l_metal2,l_metal2)]+2*minimum_enclosure[(l_metal2, l_via1)]
#	print("Minimum Spacing "+str(min_spacing[(l_via1, l_via1)])+" for via1 too small because of metal2, minimum should be "+ str(newmin)+"(="+str(min_spacing[(l_metal2,l_metal2)])+"+2*"+str(minimum_enclosure[(l_metal2, l_via1)])+") Fixing minimum_spacing")
#	min_spacing[(l_via1, l_via1)]=newmin



    #(l_poly_contact, l_pdiff_contact): 170*nm, # (licon.2)
    #(l_poly_contact, l_ndiff_contact): 170*nm, # (licon.2)
#unit_cell_height=10
#routing_grid_pitch_y=4

#print("unit_cell_height: "+str(unit_cell_height))
#print("routing_grid_pitch_y: "+str(routing_grid_pitch_y))
middle=unit_cell_height//2
#print("Middle: "+str(middle))
gridpoints=1+unit_cell_height//routing_grid_pitch_y
#print("gridpoints: "+str(gridpoints))
odd=gridpoints &1
#print("odd: "+str(odd))

if odd==1:
    grid_offset_y=middle-((gridpoints-1)//2)*routing_grid_pitch_y
else:
    grid_offset_y=middle+routing_grid_pitch_y//2-(gridpoints//2)*routing_grid_pitch_y

print("grid_offset_y: "+str(grid_offset_y))
print("grid_offset_x: "+str(grid_offset_x))
print("routing_grid_pitch_x: "+str(routing_grid_pitch_x))

grid_ys = list(range(grid_offset_y, grid_offset_y + unit_cell_height, routing_grid_pitch_y))

#print("y_grid_before: "+str(grid_ys))
#grid_ys[2] += 110*nm
#grid_ys[-3] -= 110*nm
#grid_ys[14] -= 10*nm
#grid_ys[1] = 0
#grid_ys[-2] = unit_cell_height
#grid_ys.pop(-1)
#grid_ys.pop(0)
#print("y_grid_after: "+str(grid_ys))

#grid_xs = list(range(grid_offset_x, grid_offset_x + unit_cell_width, routing_grid_pitch_x))
#print("x_grid_after: "+str(grid_xs))
#print("grid_offset_x"+str(grid_offset_x))
#print("unit_cell_width"+str(unit_cell_width))
#print("routing_grid_pitch_x"+str(routing_grid_pitch_x))



#def powervias(unit_cell_width): 
#    return list(range(240*nm,unit_cell_width,480*nm))

#power_vias=powervias

