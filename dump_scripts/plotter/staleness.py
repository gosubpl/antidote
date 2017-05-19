#! /usr/bin/env python

import matplotlib.pyplot as plt
import matplotlib.ticker as mtick

import os
import numpy as np
import csv
import sys

# Takes staleness CSV file as argument
# Global vars
results = []

# Functions
def parse_single_file(filename):
    if os.path.isfile(filename):
        print "Treating", filename
        with open(filename, 'r') as f:
            reader = csv.reader(f)
            percentages = []
            ratios = { 'wload' : "", 'percs' : [] }
            for row in reader:
                summ = 0.0
                for a in row:
                    dats = a.split('\t')
                    total = dats[1]
                    reads = dats[4:]
                    ratio = 0.0
                    if total == "Total":
                        continue
                    wload = dats[0]
                    for i in reads:
                        if i == '':
                            continue
                        ratio = float(int(i))/float(int(total))*100
                        summ += ratio
                        print "-------------> i:", i, "sum", summ, "ratio:", ratio
                        percentages.append(summ)
                    ratios['wload'] = wload
                    ratios['percs'] = percentages
                    results.append(ratios)

# Main
if len(sys.argv) == 1:
    print "Directory not specified, defaulting to cwd"
    rdir = '.'
elif len(sys.argv)>=2:
    files = sys.argv[1:]
    #styles = ['-vr', '-vk'] # For 10	
    #styles = ['-sr', '-sk'] # For 100
    #styles = ['-v'+col, ':o'+col, '-.o'+col]
    styles = ['-or', '-sr', '-vr', '-ok', '-sk', '-vk']

    for ff, style in zip(files, styles):
        if os.path.isfile(ff):
            parse_single_file(ff)
            #print "Results", results
            x = range(0, 1000)
            y = results[0]['percs']
            l_y = len(y)
            ya = []
            for a in y:
                a = a * 100
                ya.append(a)
            xa = x[:l_y]
            print "xa", xa, "y", y
            #plt.yscale('log')
            plt.ylabel("Percentage")
            plt.xlabel("# versions skipped")
            print "Plotting"
            #style = '-vr'
            plt.plot(xa, y, style)
            plt.ticklabel_format(useOffset=False)
            results [:] = []
        else:
            print ff, "not a file, skipping"
            continue
        #plt.ylim(99.95, 100.1)
    plt.xlim(-0.2)
    plt.show()
    


              ## Triangle 10
              ## Square 100
              ## PhyX black
              ## Clock Red
              ## styles = ['-v'+col, ':s'+col, '-.o'+col]
