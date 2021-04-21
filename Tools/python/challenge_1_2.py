
# find function will find that line in the report and will print frequency in MHz and GHz.

from sys import argv
import math

def round_down(n, decimals=0):
    multiplier = 10 ** decimals
    return math.floor(n * multiplier) / multiplier
    
def find(txt):
    for line in txt.readlines():
        if 'frequency' in line:
            frequency = line.split()
            freq = float(frequency[7])
            if (frequency[8] == 'MHz'):
                print ("\nMaximum frequency in", frequency[8] ,"is: ",frequency[7],frequency[8])
                print ("\nMaximum frequency in GHz is: ",round_down(freq/1000,7),"GHz")
            if (frequency[8] == 'KHz'):
                print ("\nMaximum frequency in", frequency[8] ,"is: ",frequency[7],frequency[8])
                print ("\nMaximum frequency in MHz is: ",round_down(freq/1000,7),"MHz")
                print ("\nMaximum frequency in GHz is: ",round_down(freq/1000000,9),"GHz")
            break   
            
    if 'frequency' not in line:        
        print ("Check input file again")
     
            
print ("Enter the filename:")
filename = input()
txt = open(filename)

find(txt)

txt.close()


