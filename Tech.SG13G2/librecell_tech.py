from lclayout.layout.layers import *
from lclayout.writer.magic_writer import MagWriter
from lclayout.writer.lef_writer import LefWriter
from lclayout.writer.gds_writer import GdsWriter
from lclayout.writer.oasis_writer import OasisWriter

name = "SG13G2"

# Physical size of one data base unit in meters.
# BUT GDS2 requires the database units to be in nanometers, and lclayout cannot convert to nanometers automatically yet
db_unit = 1e-9

# Lambda - how many db_units is 1 lambda?
l = 55  # unused
grid = 5 # grid basis
um = 1000
nm = 1

# Scale transistor width.
transistor_channel_width_sizing = 1

# GDS2 layer numbers for final output.
my_diffusion = (1, 0) # = ndiffusion+pdiffusion
my_diffusion_label = (1, 1)
my_diffusion_pin = (1, 2)

my_nwell = (31,0)
my_nwell_label = (31, 1)
my_nwell_pin = (31, 2)

my_pwell = (46, 0) # This layer is only used for resistors, which we dont need here

my_poly = (5, 0) # poly silicium for gates -> poly + ntransistor + ptransistor
my_poly_label = (5, 2)

my_via1 = (19, 0)

my_mcon = (6, 0) # Contact / Metal1 to Active or Poly2 contact

my_metal1 = (8, 0) # "Local Interconnect"  (like the first metal layer)
my_metal1_label = (8, 1)
my_metal1_pin = (8, 2)

my_metal2 = (10, 0)
my_metal2_label = (10, 1)
my_metal2_pin = (10, 2)

my_abutment_box = (189,4) # prBndry  ???
#my_outline = (235, 5) # 

my_pplus = (14,0) # PSD
my_nplus = (7,0) # NSD

# lclayout internally uses its own layer numbering scheme.
# For the final output the layers can be remapped with a mapping
# defined in this dictioinary.
output_map = {
    l_ndiffusion: my_diffusion,
    l_pdiffusion: my_diffusion,
    l_nwell: my_nwell,
    l_pwell: my_pwell,
    l_poly: my_poly,
    l_poly_contact: my_mcon,
    l_pdiff_contact: my_mcon,
    l_ndiff_contact: my_mcon,
    l_metal1: my_metal1,
    l_metal1_label: my_metal1,
    l_metal1_pin: my_metal1,
    l_via1: my_via1,
    l_metal2: my_metal2,
    l_metal2_label: my_metal2,
    l_metal2_pin: my_metal2,
    l_pplus: my_pplus,
    l_nplus: my_nplus,
}

# These are only the obstruction layers, only these layers will be generated into the OBS section of the LEF files
obstruction_layers = [
    l_poly_contact,
    l_pdiff_contact,
    l_ndiff_contact,
    l_metal1,
    l_metal2,
    l_via1,
]

output_map_magic = {
            l_nwell: l_nwell,
            l_pwell: l_pwell,
            l_via1: l_via1,
            l_poly: l_poly,
            l_abutment_box: ['abutment'],
            l_metal1: l_metal1,
            l_metal2: l_metal2,
            l_metal1_label: l_metal1,
            l_metal2_label: l_metal2,
            l_metal1_pin: l_metal1,
            l_metal2_pin: l_metal2,
            l_ndiffusion: l_ndiffusion,
            l_pdiffusion: l_pdiffusion,
            l_poly_contact: "allcont",
            l_pdiff_contact: "allcont",
            l_ndiff_contact: "allcont",
            l_nplus: "nsd",
            l_pplus: "psd",
}


# Define a list of output writers.
output_writers = [
    MagWriter(
        tech_name='ihp-sg13g2',
        #scale_factor=0.2, # Scale all coordinates by this factor (rounded down to next integer).
        #magscale=[1,2],
        output_map=output_map_magic
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
    l_poly: '',
    l_metal1: 'hv',
    l_metal2: 'hv',
}

# Minimum spacing rules for layer pairs.
min_spacing = {
    (l_ndiffusion, l_ndiffusion): 270*nm,
    (l_pdiffusion, l_ndiffusion): 270*nm,
    (l_pdiffusion, l_pdiffusion): 270*nm,
    (l_ndiffusion, l_poly_contact): 190*nm,
    (l_pdiffusion, l_poly_contact): 190*nm,
    (l_poly_contact, l_poly_contact): 190*nm,
    (l_nwell, l_nwell): 1270*nm,
    (l_nwell, l_pwell): 250*nm,
    (l_pwell, l_pwell): 1270*nm,
    (l_poly, l_ndiffusion): 75*nm,
    (l_poly, l_pdiffusion): 75*nm,
    (l_poly, l_poly): 210*nm,
    (l_poly, l_pdiff_contact): 180*nm,
    (l_poly, l_ndiff_contact): 180*nm,
    (l_pdiff_contact, l_pdiff_contact): 270*nm,
    (l_ndiff_contact, l_ndiff_contact): 270*nm,
    (l_pdiff_contact, l_ndiff_contact): 270*nm,
    (l_metal1, l_metal1): 180*nm,
    (l_metal2, l_metal2): 180*nm,
    (l_via1, l_via1): 190*nm,
    (l_poly_contact, l_pdiff_contact): 180*nm,
    (l_poly_contact, l_ndiff_contact): 180*nm,
    (l_ndiffusion, l_pplus): 75*nm,
    (l_pdiffusion, l_nplus): 75*nm,
}

# Layer for the pins.
pin_layer = l_metal2 # lclayout.metal2 = sky130.metal1

# Power stripe layer
power_layer = [l_metal1] # , l_metal2] # lclayout.metal2 = sky130.metal1

# Layers that can be connected/merged without changing the schematic.
# This can be used to resolve spacing/notch violations by just filling the space.
connectable_layers = {l_nwell, l_pwell, l_poly}
# Width of the gate polysilicon stripe.
# is reused as the minimum_width for the l_poly layer
#gate_length_pmos = 280*nm # 140 # 70
gate_length_pmos = 340*nm
gate_length_nmos = 340*nm

# Minimum length a polysilicon gate must overlap the silicon.
gate_extension = 130*nm # (poly.8)

# Minimum distance of active area to upper or lower boundary of the cell. Basically determines the y-offset of the transistors.
#transistor_offset_y = 240*nm # !!! This likely needs to be tuned later on # The 180/2*nm might have to be removed
#transistor_offset_y = 0
transistor_offset_y = 235*nm

# Standard cell dimensions.
# A 'unit cell' corresponds to the dimensions of the smallest possible cell. Usually an inverter.
# `unit_cell_width` also corresponds to the pitch of the gates because gates are spaced on a regular grid.
unit_cell_width = 1440*nm # 480*3 (unit SITE) # 1380*nm # 920 is 2*0.46um (unithd SITE),  8 * 130*nm
#unit_cell_width = 3330*nm # 480*3 (unit SITE) # 1380*nm # 920 is 2*0.46um (unithd SITE),  8 * 130*nm
unit_cell_height = 3330*nm # (unit SITE) # 2720*nm #270*nm # 32 * 130*nm # minimum 16um due to pwell width + nwell-pwell spacing
#assert unit_cell_height >= 16*um, "minimum 16um due to pwell width + nwell-pwell spacing"
# due to nwell size and spacing requirements routing_grid_pitch_y * 8 # * 8

# Routing pitch
routing_grid_pitch_x = unit_cell_width // 6 # unit_cell_width // 8 // 2
routing_grid_pitch_y = 340*nm #unit_cell_height // 8 // 2

# Translate routing grid such that the bottom left grid point is at (grid_offset_x, grid_offset_y)
grid_offset_x = routing_grid_pitch_x
grid_offset_y = 0 # 0 # (routing_grid_pitch_y // 2 ) -10

# Width of power rail.
power_rail_width = 480*nm # compatible to SKY130 #  3*130*nm # decided by the standard cell library architect

# Minimum width of polysilicon gate stripes.
# It increases w and l from the spice netlist, so it must be width from the spice netlist
minimum_gate_width_nfet = gate_length_nmos*nm # (poly.1a)
minimum_gate_width_pfet = gate_length_pmos*nm # (poly.1a)

# Minimum width for pins.
minimum_pin_width = 130*nm 

# Width of routing wires.
wire_width = {
    l_ndiffusion: 180*nm,
    l_pdiffusion: 180*nm,
    l_poly: 180*nm,
    l_metal1: 180*nm,
    l_metal2: 180*nm,
}

# Width of horizontal routing wires (overwrites `wire_width`).
wire_width_horizontal = {
    l_ndiffusion: 180*nm,
    l_pdiffusion: 180*nm,
    l_poly: 180*nm,
    l_metal1: 180*nm,
    l_metal2: 180*nm,
}

# Side lengths of vias (square shaped).
via_size = {
    l_poly_contact: 190*nm,
    l_ndiff_contact: 190*nm,
    l_pdiff_contact: 190*nm,
    l_via1: 190*nm,
}

# Minimum width rules.
minimum_width = {
    l_pplus: 180*nm,
    l_nplus: 180*nm,
    l_ndiffusion: 180*nm,
    l_pdiffusion: 180*nm,
    l_poly: 180*nm, # (poly.1a), 
    l_metal1: 180*nm,
    l_metal2: 180*nm,
    l_nwell: 620*nm,
    l_pwell: 620*nm    
}

minimum_enclosure = {
    (l_ndiffusion, l_ndiff_contact): 60*nm,
    (l_pdiffusion, l_pdiff_contact): 60*nm,
    (l_poly, l_poly_contact): 80*nm,
    (l_metal1, l_pdiff_contact): 80*nm,
    (l_metal1, l_ndiff_contact): 80*nm,
    (l_metal1, l_poly_contact): 80*nm,
    (l_metal1, l_via1): 0*nm,
    (l_metal2, l_via1): 60*nm,
    (l_pwell, l_ndiffusion): 180*nm,
    (l_nwell, l_pdiffusion): 180*nm,
    (l_abutment_box, l_nwell): 0,
    (l_abutment_box, l_pwell): 0,
    (l_nplus, l_ndiff_contact): 80*nm,
    (l_pplus, l_pdiff_contact): 80*nm,
}

# Minimum notch rules.
minimum_notch = {
    l_ndiffusion: 130*nm,
    l_pdiffusion: 130*nm,
    l_poly: 130*nm,
    l_metal1: 180*nm,
    l_metal2: 180*nm,
    l_nwell: 5*130*nm,
    l_pwell: 5*130*nm,
}

# Minimum area rules.
min_area = {
    l_metal1: 0.0561 * um * um ,#  !!! TEMPORARILY DISABLED, PLEASE ENABLE AGAIN
    l_metal2: 0.083 * um * um ,# !!! TEMPORARILY DISABLED, PLEASE ENABLE AGAIN
}

# ROUTING #

# Cost for changing routing direction (horizontal/vertical).
# This will avoid creating zig-zag routings.
orientation_change_penalty = 100000

# Routing edge weights per data base unit.
weights_horizontal = {
    l_ndiffusion: 120000, # (mohms/square) taken from spreadsheet "Layer resistances and capacitances"
    l_pdiffusion: 197000, # (mohms/square)
    l_poly: 48200*10, # (mohms/square) # 10 to avoid routing
    l_metal1: 1280, # SKY130_Li1 Local Interconnect! (mohms/square)
    l_metal2: 125, # SKY130_Metal1
}
weights_vertical = {
    l_ndiffusion: 120000, # (mohms/square) taken from spreadsheet "Layer resistances and capacitances"
    l_pdiffusion: 197000, # (mohms/square)
    l_poly: 48200*10, # (mohms/square) # 10 to avoid routing
    l_metal1: 1280, # SKY130_Li1 Local Interconnect! (mohms/square)
    l_metal2: 125, # SKY130_Metal1
}

viafactor = 1

# Via weights.
via_weights = {
    (l_metal1, l_ndiffusion): 18000*viafactor,
    (l_metal1, l_pdiffusion): 18000*viafactor,
    (l_metal1, l_poly): 18000*viafactor,
    (l_metal1, l_metal2): 152000*viafactor,
}

# Enable double vias between layers.
multi_via = {
#    (l_metal1, l_poly): 1,
#    (l_metal1, l_metal2): 1,
}



grid_ys = list(range(grid_offset_y, grid_offset_y + unit_cell_height +1, routing_grid_pitch_y))
print("grid_after: "+str(grid_ys))
