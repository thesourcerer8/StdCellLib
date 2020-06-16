
# find function will find that n paths in the report, will display them and also highlight the critical path of circuit.

from sys import argv

def find(txt,tmp,path):
    formatter = " {} \n"
    setup = open("setup.txt","w+")
    hold = open("hold.txt","w+")
    for line in txt.readlines():
        if 'Path' in line or 'setup' in line or 'hold a' in line:
            text = line.split()
            for i in range(len(text)): 
                if text[i] == 'delay' :
                    tmp.write(text[i+1])
                if text[i] == 'setup' or text[i] == 'hold':
                    tmp.write(formatter.format(text[i]))       
    
    tmp.seek(0,0)
    for line in tmp.readlines():
        if 'setup' in line: 
            setup.write(formatter.format(line.split()[0]))
        if 'hold' in line: 
            hold.write(formatter.format(line.split()[0]))
            
    setup.seek(0,0)
    hold.seek(0,0)
    data_s = setup.readlines()
    data_h = hold.readlines()
    data_s.sort(key = float,reverse = True)
    data_h.sort(key = float,reverse = True)
    converted_data_s = []
    converted_data_h = []
    
    for element in data_s:
        converted_data_s.append(element.strip())
    for element in data_h:
        converted_data_h.append(element.strip())   
       
    print ("\n\n{:<15} {:<15} {:<10}\n".format('Path Number','For Setup','For Hold'))
    
    if path == 0 or path > len(data_s):
        for i in range(len(data_s)):
            print ("{:<15} {:<15} {:<10}".format(i+1,converted_data_s[i],converted_data_h[i]))
    else:           
        for i in range(path):        
            print ("{:<15} {:<15} {:<10}".format(i+1,converted_data_s[i],converted_data_h[i])) 
            
    txt.seek(0,0)
    tmp.seek(0,0)
    temp = tmp.readline().split()[0]
    for line in txt.readlines():
        if temp in line:
            print ("\n Critical Path: ",line)
            break   
        
    setup.close()
    hold.close()         
                                   
print ("Enter the filename:")
filename = input()
print ("Enter the number of path")
path = int(input())
txt = open(filename)
tmp = open("tmp.txt","w+")

find(txt,tmp,path)

txt.close()
tmp.close()

