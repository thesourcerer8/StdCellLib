import sys
import os

def expand_lib(ifpath,line):
    ret=""
    words = line.split()
    if len(words) > 1:
        _ifile = words[1]
    else:
        return ret
    
    _ifile = _ifile.replace('"','')

    if not os.path.isabs(_ifile):
        _ifile = os.path.join(ifpath,_ifile)

    _ifpath = os.path.dirname(os.path.realpath(_ifile))

    with open(_ifile,'r') as file:
        lines = file.read()
        file.close()
    lines = lines.split('\n')
    for line in lines:
        if line.lower().strip().startswith(".include"):
            ret+=expand_lib(_ifpath,line)
        else:
            ret+=line+'\n'
    return ret

if __name__ == "__main__":
     if len(sys.argv)==4:
          libname = sys.argv[1]
          ifname = sys.argv[2]
          ifpath = os.path.dirname(os.path.realpath(ifname))
          ofname = sys.argv[3]
          has_begun=False
          ret=""
          with open(ifname,'r') as file:
                lines = file.read()
                file.close()
          lines = lines.split('\n')
          for line in lines:
                if not has_begun and line.lower().startswith(".lib"):
                     words = line.split()
                     if len(words) > 1:
                          if words[1] == libname:
                                has_begun=True
                          ret+=".LIB typical\n"
                elif has_begun and line.lower().startswith(".endl"):
                     ret+=".ENDL typical\n"
                     break
                elif line.lower().strip().startswith(".include"):
                     ret+=expand_lib(ifpath,line)
                else:
                     ret+=line+'\n'

          with open(ofname,'w') as file:
                file.write(ret)
                file.close()
     else:
          print("Input and output file requires!")
          print("usage: python expand typical_name in.spice out.spice")
          print("typical name -> tt or whatever, name of lib to select, will be renamed to typical")
          print("the other two are file names")
