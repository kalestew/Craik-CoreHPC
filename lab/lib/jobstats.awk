# sacct allocation rows own CPU accounting. Steps contribute memory only;
# adding their CPU again would double-count an srun job.
function seconds(s, d, a, n, p) {
    if (s !~ /^([0-9]+-)?[0-9]+(:[0-9]+)*([.][0-9]+)?$/) return -1
    d=0
    if (index(s,"-")) { split(s,a,"-"); d=a[1]; s=a[2] }
    n=split(s,p,":")
    if (n==3) return d*86400+p[1]*3600+p[2]*60+p[3]
    if (n==2) return d*86400+p[1]*60+p[2]
    if (n==1) return d*86400+p[1]
    return -1
}
function mb(s, bare, u, v) {
    if (s !~ /^[0-9]+([.][0-9]+)?[KMGTkmgt]?$/) return -1
    u=toupper(substr(s,length(s),1)); v=s+0
    if (u=="K") return v/1024
    if (u=="M") return v
    if (u=="G") return v*1024
    if (u=="T") return v*1048576
    return bare ? v : v/1048576
}
function requested(s, cores, v, pc) {
    pc=(s ~ /c$/); sub(/[cn]$/,"",s)
    v=mb(s,1)
    return v < 0 ? -1 : v*(pc ? cores : 1)
}
function group(id, a) { split(id,a,"_"); return a[1] }
{
    id=$1
    if (id ~ /[.]/) {
        base=id; sub(/[.].*$/,"",base)
        if (id ~ /[.]extern$/) next
        v=mb($8,0)
        if (v>rss[base]) rss[base]=v
        if (id !~ /[.]batch$/ || $12+0>1) complex[base]=1
        next
    }
    if (id !~ /^[0-9]+([+_][0-9]+)?$/) next
    order[++count]=id
    name[id]=$2; state[id]=$3; elapsed[id]=$4; cpu[id]=$5
    cores[id]=$6+0; req[id]=$7; nodes[id]=$11+0
    if ($12+0>1) complex[id]=1
    g=group(id)
    if (!(g in groups)) { groups[g]=1; group_order[++ng]=g }
}
END {
    if (!count) { print "chpc-jobstats: no allocation rows parsed" > "/dev/stderr"; exit 1 }
    printf "%-22s %-22s %6s %6s %8s %12s %12s\n", "JOB","NAME","DONE","CORES","CPU-EFF","MAXRSS(M)","MEM-REQ(M)"
    for (j=1;j<=ng;j++) {
        g=group_order[j]; total=0; done=0; skipped=0; failures=0
        sumcpu=0; capacity=0; maxrss=0; maxreq=0; nc=0; peakused=0; unsafe=0; missing=0; firstnc=0
        worst=1e9; best=0
        for (i=1;i<=count;i++) {
            id=order[i]; if (group(id)!=g) continue
            total++; nm=name[id]
            if (state[id]!="COMPLETED") {
                skipped++
                if (state[id] ~ /^(FAILED|OUT_OF_MEMORY|TIMEOUT|NODE_FAIL|CANCELLED)/) failures++
                continue
            }
            e=seconds(elapsed[id]); c=seconds(cpu[id]); n=cores[id]
            if (e<=0 || c<0 || n<=0) { missing++; continue }
            done++; sumcpu+=c; capacity+=e*n
            if (n>nc) nc=n
            if (!firstnc) firstnc=n
            if (n!=firstnc || nodes[id]!=1 || complex[id]) unsafe=1
            u=c/e; if (u>peakused) peakused=u
            eff=c/(e*n); if (eff<worst) worst=eff; if (eff>best) best=eff
            if (rss[id]>maxrss) maxrss=rss[id]
            if (rss[id]<=0) missing++
            r=requested(req[id],n); if (r>maxreq) maxreq=r
        }
        if (!done) {
            printf "%-22s %-22s %6d      ?        ?            ?            ?\n", g,nm,done
            print "  no completed task with usable CPU accounting; no sizing recommendation."
            continue
        }
        printf "%-22s %-22s %6d %6d %8.3f %12s %12s\n", g,nm,done,nc,sumcpu/capacity,(maxrss>0?sprintf("%.1f",maxrss):"?"),(maxreq>0?sprintf("%.0f",maxreq):"?")
        printf "  %d of %d allocation(s) completed; CPU efficiency range %.4f-%.4f.\n",done,total,worst,best
        if (failures || unsafe || missing) {
            printf "  no sizing recommendation: %d failed/timed-out allocation(s); ",failures
            printf "%d unsupported multi-node/step or mixed-core layout; %d missing accounting value(s).\n",unsafe,missing
            print "  MaxRSS is a per-task high-water, not the sum across srun ranks. Inspect the steps."
        } else {
            suggested=int(peakused); if (suggested<peakused) suggested++
            if (suggested<1) suggested=1
            printf "  cores: peak task-average usage %.2f of %d allocated; ",peakused,nc
            if (suggested<nc)
                printf "consider --cpus-per-task=%d only after checking the program and workload.\n",suggested
            else print "no reduction indicated."
            memory=maxrss*4/1024; sm=int(memory); if (sm<memory) sm++; if (sm<1) sm=1
            printf "  memory: measured maximum %.1f M; --mem=%dG gives 4x headroom (1G minimum).\n",maxrss,sm
        }
        if (total>1) {
            printf "  array: %d allocations; %%N limits simultaneous tasks, so N x CPUs/task is the core budget.\n",total
            print "  Check all active jobs, partition/job QoS, node limits and placement before raising N."
        }
        print ""
    }
    if (tasks) {
        printf "%-22s %-22s %12s %12s %6s %8s\n","TASK","STATE","ELAPSED","TOTALCPU","CORES","CPU-EFF"
        for (i=1;i<=count;i++) {
            id=order[i]; e=seconds(elapsed[id]); c=seconds(cpu[id]); n=cores[id]
            eff=(state[id]=="COMPLETED" && e>0 && c>=0 && n>0)?sprintf("%.3f",c/(e*n)):"?"
            printf "%-22s %-22s %12s %12s %6d %8s\n",id,state[id],elapsed[id],cpu[id],n,eff
        }
    }
}
