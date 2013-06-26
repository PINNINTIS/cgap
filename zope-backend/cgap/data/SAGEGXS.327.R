p<- scan("/share/content/CGAP/data/SAGEGXS.327.BH_IN")
p_BH<-p.adjust(p,"BH")
write(file = "/share/content/CGAP/data/SAGEGXS.327.BH_OUT", p_BH, sep = "
", append=T)
