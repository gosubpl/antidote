#! /usr/bin/env python

import matplotlib.pyplot as plt
import os
import numpy as np
import csv
import sys
from os.path import splitext

# Usage:
# $ <script> [<dir1> <dir2> <dir3> ...]
# The script's directory (the command line arguments)  should be structured as suc
# $ tree ../multi-dc-multiround/bench-2017-04-12-1492030851-clocksi/
#  ../multi-dc-multiround/bench-2017-04-12-1492030851-clocksi/
#  |-- basho_bench_summary-1000000-10-100-10-1
#  |   |-- summary.csv
#  |   |-- summary.png
#  |   |-- txn_latencies.csv
#  |-- basho_bench_summary-1000000-10-100-10-10
#  |   |-- summary.csv
#  |   |-- summary.png
#  |   |-- txn_latencies.csv
#  ...

# Workload structure is a key value dictionary:
# workload = 
# 'type'    : Basho bench or staleness
# 'keys'    : 1m or 10m
# 'rounds'  : 10 usually
# 'reads'   : 100 usually
# 'writes'  : one from [2, 10, 100]
# 'threads' : one from [1, 3, 5, 7, 10, 15, 20, 30, 40]
# 'f_tput'  : summary csv file
# 'f_lat'   : latency csv file
# 'tput_avg : average throughput (calculated as average of 3 values)
# 'lat_avg  : average latency (calculated as average of 3 values)

# Workload type for graphing
# wload_type = 
# 'reads'   : # of reads per round
# 'writes'  : # of writes per round
# 'threads' : # of threads/clients

#General algo: 
#Foreach type in [Physics, ClockSI, EC]
#  Foreach keyspace in [1m, 10m]
#    Foreach thread_nb in [1 3 5 7 10 15 20 30 40]
#      Plot latency (mean and 99th percentile [(30s+40s+50s)/3]) against throughput
#        1 graph
#	 3 lines, one for each pair from [[100, 2], [100, 10], [100, 100]

# Changelog (use C-u M-! date for date)
# x - fix
# + - add
# - - remove

# Thu Apr 19 2017
# + filtering threshold value 
# x latency and tput parsing
# x Cleaning, proper functions
# Thu Apr 20 2017
# x Fixed directories handling, can now drag and drop from finder
# x Sorting 


def print_workloads():
    for wload in workloads:
        print "---------"
        for el in wload:
            print el, wload[el]
 
# Gets the 30s, 40s, 50s values and calculates their mean,
# then adds it to workload structure
def load_tput():
    for e in workloads:
        reads = int(e['reads'])
        rounds = int(e['rounds'])
        writes = int(e['writes'])
        avg = 0
        with open(e['f_tput']) as f:
            reader = csv.reader(f)
            reader.next()
            for row in reader:
                elapsed, window, total, successful, failed = row
                elapsed = int(float(elapsed))
                #if elapsed == 10:
                if elapsed==20 or elapsed == 30 or elapsed == 40:
                    avg += int(successful)
        e['avg_tput']= float(((avg/3)/10)*((rounds*reads)+writes))/1000000 # MultiDC MultiRound
        #e['avg_tput']= float(((avg/3)/10)*(1022+writes))/1000000 # For exponential

# Stores latencies in corresponding arrays
def load_lat():
    for e in workloads:
        avg = 0.
        with open(e['f_lat']) as f:
            reader = csv.reader(f)
            reader.next()
            for row in reader:
                elapsed, _, _, _, mean, _, _, _, _, _, _  = row
                elapsed = int(float(elapsed))
                if elapsed==20 or elapsed == 30 or elapsed == 40:
               #if elapsed == 10:
                    mean = float(mean)
                    avg += mean
        e['avg_lat']= float((avg/3))/1000
        #e['avg_lat']= (avg)/1000

def parse_dir(rootdir):
    first = True
    for root, dirs, files in os.walk(rootdir):
        if first:
            first=False
            continue
        asd = rootdir.split("-")
        parse_workload(root, asd[-1])

                    
# Populates the structures from directories at @rootdir
# @rootdir should contain the tx_latencies.csv and summary.csv
def parse_workload(rootdir, tpe):
    if os.path.isdir(rootdir):
        b_name = os.path.basename(rootdir)
        _, keys, rounds, reads, writes, threads = b_name.split("-")
        workload = {'type' : tpe, 'keys' : keys, 'rounds' : rounds, 'reads' : reads, 'writes' : writes, 'threads' : threads, 'f_tput' : "", 'f_lat' : ""}
        for ff in os.listdir(rootdir):
            if ff == "summary.csv":
                sum_f = ff
                workload['f_tput'] = str(rootdir)+"/"+str(sum_f)
            if ff == "txn_latencies.csv":
                lat_f = ff
                workload['f_lat'] = str(rootdir)+"/"+str(lat_f)
        workloads.append(workload)

def populate_points(wload, writes):
    # First filter by writes number
    tmp_wload = []
    one_lat=[]
    one_tx=[]
    ten_lat=[]
    ten_tx=[]
    one_th = []
    ten_th = []
    for w in wload:
        if w['keys'] == "1000000" and w['writes'] == str(writes):
            if w['avg_lat']==0 or w['avg_tput']==0:
                continue
            one_lat.append(w['avg_lat'])
            one_tx.append(w['avg_tput'])
            one_th.append(w['threads'])
        elif w['keys'] == "10000000" and w['writes'] == str(writes):
            if w['avg_lat']==0 or w['avg_tput']==0:
                continue
            ten_lat.append(w['avg_lat'])
            ten_tx.append(w['avg_tput'])
            ten_th.append(w['threads'])
    return one_lat, one_tx, one_th, ten_lat, ten_tx, ten_th

def plot(workload):
    exp=workload[0]['type']
    # Colors assignment
    if exp == "physics":
        exp = "CR"
        col = 'k'
    elif exp == "clocksi":
        exp = "CAV"
        col = 'r'
    elif exp == "cure":
        exp = "CAV-B"
        col = 'b'
    else: # EC
        exp = "AR"
        col = 'g'
    #styles = ['-'+col, ':'+col, '-.'+col]
    styles = ['-v'+col, ':s'+col, '-.o'+col]
    #styles = ['v'+col, 's'+col, 'o'+col]

    "------------------------------------------------ WRITES ------------------"
    writes = [10, 100]
    # 2 -> 0.2%
    # 10 -> 1%
    # 100 -> 10%
    for wr, st in zip(writes, styles):
        tputs_one = []
        lats_one = []
        tputs_ten = []
        lats_ten = []
        plot_data_one_mil[:] = []
        plot_data_ten_mil[:] = []
        onemil_lat, onemil_txput, one_th, tenmil_lat, tenmil_txput, ten_th = populate_points(workloads, wr)
        print "Generating", exp, "for", wr, "writers"
        for l, tp, th in zip(tenmil_lat, tenmil_txput, ten_th):
            p = { 'l_tp' : [l, tp], 'th' : th }
            plot_data_ten_mil.append(p)

        for l, tp, th in zip(onemil_lat, onemil_txput, one_th):
            p = { 'l_tp' : [l, tp], 'th' : th }
            plot_data_one_mil.append(p)
            
#        tenmil_lat = [x for x in tenmil_lat if x > 5]
#        l = len(tenmil_lat)*-1
#        tenmil_txput = tenmil_txput[l:]
        om_label = exp+" k:1m w:" + str(wr)
        if wr == 10:
            tm_label = exp+" w: 10%"
        elif wr == 100:
            tm_label = exp+" w: 100%"
        sorted_one = sorted(plot_data_one_mil, key=lambda k: int(k['th']))
        sorted_ten = sorted(plot_data_ten_mil, key=lambda k: int(k['th']))

        for k in sorted_ten:
            print "-->", k
        
        for i in sorted_one:
            tput = i['l_tp'][1]
            lat = i['l_tp'][0]
            tputs_one.append(tput)
            lats_one.append(lat)
            
        for i in sorted_ten:
            if exp=="CR": # Physics hacks
                lat = i['l_tp'][0]
            else:
                lat = i['l_tp'][0]
            tput = i['l_tp'][1]

            tputs_ten.append(tput)
            lats_ten.append(lat)

            #print "1m:", plot_data_one_mil, "\n10m", plot_data_ten_mil
        plt.plot(tputs_ten, lats_ten, st, label=tm_label)
        #plt.plot(tputs_one, lats_one, st, label=om_label)


        plt.legend(loc='best')

        tputs_ten[:] = []
        lats_ten[:] = []
        tputs_one[:] = []
        lats_one[:] = []
        onemil_lat[:] = []
        onemil_txput[:] = []
        tenmil_lat[:] = []
        tenmil_txput[:] = []


# Main
rdir=[]
picture = "graph.png"
if len(sys.argv) == 1:
    print "Directory not specified, defaulting to cwd"
    rdir = '.'
elif len(sys.argv)>=2:
    for d in sys.argv:
        if os.path.isdir(d):
            rdir.append(d)

for d in rdir:
    print "Treating", d
    workloads = []
    onemil_lat = []
    onemil_txput = []
    tenmil_lat = []
    tenmil_txput = []
    pairs = []
    plot_data_one_mil = []
    plot_data_ten_mil = []
        
    parse_dir(d)
    load_tput()
    load_lat()
    
    plot(workloads)
    # Plot part
#title = "Multi DC Multi Round"
#plt.suptitle(title)
#plt.ylim(150, 240)
plt.ylabel('Latency [ms]')
plt.xlabel('Throughput [million ops/sec]')
print "Plotting graph..."
#plt.savefig("lel.png", dpi=600)
print "Showing interactive graph..."
#print_workloads()
plt.show()
