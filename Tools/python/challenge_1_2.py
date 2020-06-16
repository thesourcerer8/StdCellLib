
# find function will find that line in the report and will print frequency in MHz and GHz.

from sys import argv

def find(txt):
    for line in txt.readlines():
        if 'frequency' in line:
            frequency_MHz = line.split()
            print ("\nMaximum frequency in MHz is: ",frequency_MHz[7],"MHz")
            frequency = float("".join(frequency_MHz[7]))
            print ("\nMaximum frequency in GHz is: ",frequency/(1000),"GHz")
            break   
            
    if 'frequency' not in line:        
        print ("Check input file again")
     
            
print ("Enter the filename:")
filename = input()
txt = open(filename)

find(txt)

txt.close()


