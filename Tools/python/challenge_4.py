
# find function will find max delay component of critical path of circuit.

from sys import argv

def find(txt):
    prev_num = 0.0
    print ("\nDetails of max delay component of critical path of circuit is as follows:\n")
    for x,line in enumerate(txt):
        if 'Path' in line:
            print ("Critical path of the circuit is:\n",line)
            break
     
    for y,line in enumerate(txt):
        if line == '\n':
            break
    
    txt.seek(0,0)
    diffrence_list = []
    
    for position, line in enumerate(txt):
        if position in range(x+1,x+y+1):
            num = line.split()
            diffrence_list.append(float(num[0])-prev_num)
            prev_num = float(num[0])
            
    txt.seek(0,0)
    for position, line in enumerate(txt):
        if position == x+1+diffrence_list.index(max(diffrence_list)):
            extract = line.split()
            print ("Max delay component of critical path is:\n",extract[2].replace(':',''), "net whose path is ",extract[3], extract[4], extract[5],"with delay of", max(diffrence_list), "ps\n")
                                           
print ("Enter the filename:")
filename = input()
txt = open(filename)

find(txt)

txt.close()


