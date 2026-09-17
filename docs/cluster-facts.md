# CoreHPC live facts

Captured 2026-09-17 03:50 UTC on chpc-ucsf-login-vm1.corehpc.ucsf.edu by kanderson6 with scripts/chpc-discover.sh.

## Identity and groups

```
uid=1631829934(kanderson6) gid=1631829934(kanderson6) groups=1631829934(kanderson6),515962380(corehpc_tier1),515964090(corehpc_base),515967374(sec_fac_cx500146_ds1),585667944(corehpc_sbgridusers) context=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
```

## OS / kernel

```
NAME="Rocky Linux from CIQ"
VARIANT="Pro"
VARIANT_ID="pro"
VERSION="9.8 (Blue Onyx)"
5.14.0-687.24.1+2.1.el9_8_ciq.x86_64
```

## SLURM version

```
slurm 24.11.5
```

## Partitions (sinfo)

```
PARTITION AVAIL TIMELIMIT NODES CPUS MEMORY GRES NODELIST
community up 14-00:00:00 80 96 256000 (null) ccpu1-[01-80]
community_short up 1:00:00 80 96 256000 (null) ccpu1-[01-80]
cpu* up 4-00:00:00 47 336+ 1540000+ (null) gcpu2-[03-48,55]
gpu up 4-00:00:00 6 64 386000 gpu:nvidia_h100_nvl:1(S:0) ggpu4-[01-06]
gpu up 4-00:00:00 7 64 386000 gpu:nvidia_l40s:2 ggpu1-[06-12]
gpu up 4-00:00:00 7 128 380000 gpu:nvidia_rtx_pro_6000:2 ggpu1-[13-19]
large_gpu up 1-00:00:00 13 208+ 2060000 gpu:nvidia_h200:8 ggpu3-[17-29]
large_gpu up 1-00:00:00 3 256 1540000 gpu:nvidia_h200_nvl:4 ggpu5-[01-03]
pod up 4-00:00:00 8 208 2063700 gpu:nvidia_h200:8 ggpu3-[09-16]
```

## Node summary

```
PARTITION HOSTNAMES FREE_MEM MEMORY AVAIL CPUS CPUS(A/I/O/T) GRES
community ccpu1-05 N/A 256000 up 96 0/0/96/96 (null)
community ccpu1-01 48704 256000 up 96 4/92/0/96 (null)
community ccpu1-02 155398 256000 up 96 0/96/0/96 (null)
community ccpu1-03 179667 256000 up 96 0/96/0/96 (null)
community ccpu1-04 191393 256000 up 96 0/96/0/96 (null)
community ccpu1-06 191620 256000 up 96 0/96/0/96 (null)
community ccpu1-07 176617 256000 up 96 0/96/0/96 (null)
community ccpu1-08 194720 256000 up 96 0/96/0/96 (null)
community ccpu1-09 193514 256000 up 96 0/96/0/96 (null)
community ccpu1-10 140249 256000 up 96 0/96/0/96 (null)
community ccpu1-11 200869 256000 up 96 0/96/0/96 (null)
community ccpu1-12 224064 256000 up 96 0/96/0/96 (null)
community ccpu1-13 225204 256000 up 96 0/96/0/96 (null)
community ccpu1-14 240278 256000 up 96 0/96/0/96 (null)
community ccpu1-15 236341 256000 up 96 0/96/0/96 (null)
community ccpu1-16 237111 256000 up 96 0/96/0/96 (null)
community ccpu1-17 237159 256000 up 96 0/96/0/96 (null)
community ccpu1-18 238948 256000 up 96 0/96/0/96 (null)
community ccpu1-19 241465 256000 up 96 0/96/0/96 (null)
community ccpu1-20 241553 256000 up 96 0/96/0/96 (null)
community ccpu1-21 241445 256000 up 96 0/96/0/96 (null)
community ccpu1-22 241563 256000 up 96 0/96/0/96 (null)
community ccpu1-23 241671 256000 up 96 0/96/0/96 (null)
community ccpu1-24 241628 256000 up 96 0/96/0/96 (null)
community ccpu1-25 241679 256000 up 96 0/96/0/96 (null)
community ccpu1-26 241540 256000 up 96 0/96/0/96 (null)
community ccpu1-27 241530 256000 up 96 0/96/0/96 (null)
community ccpu1-28 241571 256000 up 96 0/96/0/96 (null)
community ccpu1-29 241515 256000 up 96 0/96/0/96 (null)
community ccpu1-30 241493 256000 up 96 0/96/0/96 (null)
community ccpu1-31 241539 256000 up 96 0/96/0/96 (null)
community ccpu1-32 241629 256000 up 96 0/96/0/96 (null)
community ccpu1-33 241658 256000 up 96 0/96/0/96 (null)
community ccpu1-34 241671 256000 up 96 0/96/0/96 (null)
community ccpu1-35 241545 256000 up 96 0/96/0/96 (null)
community ccpu1-36 241675 256000 up 96 0/96/0/96 (null)
community ccpu1-37 241681 256000 up 96 0/96/0/96 (null)
community ccpu1-38 241494 256000 up 96 0/96/0/96 (null)
community ccpu1-39 241468 256000 up 96 0/96/0/96 (null)
community ccpu1-40 241491 256000 up 96 0/96/0/96 (null)
community ccpu1-41 241506 256000 up 96 0/96/0/96 (null)
community ccpu1-42 241521 256000 up 96 0/96/0/96 (null)
community ccpu1-43 241616 256000 up 96 0/96/0/96 (null)
community ccpu1-44 241454 256000 up 96 0/96/0/96 (null)
community ccpu1-45 241495 256000 up 96 0/96/0/96 (null)
community ccpu1-46 241552 256000 up 96 0/96/0/96 (null)
community ccpu1-47 241630 256000 up 96 0/96/0/96 (null)
community ccpu1-48 241459 256000 up 96 0/96/0/96 (null)
community ccpu1-49 241679 256000 up 96 0/96/0/96 (null)
community ccpu1-50 241434 256000 up 96 0/96/0/96 (null)
community ccpu1-51 241337 256000 up 96 0/96/0/96 (null)
community ccpu1-52 241524 256000 up 96 0/96/0/96 (null)
community ccpu1-53 241574 256000 up 96 0/96/0/96 (null)
community ccpu1-54 241668 256000 up 96 0/96/0/96 (null)
community ccpu1-55 241459 256000 up 96 0/96/0/96 (null)
community ccpu1-56 241490 256000 up 96 0/96/0/96 (null)
community ccpu1-57 241658 256000 up 96 0/96/0/96 (null)
community ccpu1-58 241483 256000 up 96 0/96/0/96 (null)
community ccpu1-59 241691 256000 up 96 0/96/0/96 (null)
community ccpu1-60 241629 256000 up 96 0/96/0/96 (null)
community ccpu1-61 241583 256000 up 96 0/96/0/96 (null)
community ccpu1-62 241513 256000 up 96 0/96/0/96 (null)
community ccpu1-63 241519 256000 up 96 0/96/0/96 (null)
community ccpu1-64 241597 256000 up 96 0/96/0/96 (null)
community ccpu1-65 241584 256000 up 96 0/96/0/96 (null)
community ccpu1-66 241500 256000 up 96 0/96/0/96 (null)
community ccpu1-67 241465 256000 up 96 0/96/0/96 (null)
community ccpu1-68 241431 256000 up 96 0/96/0/96 (null)
community ccpu1-69 241507 256000 up 96 0/96/0/96 (null)
community ccpu1-70 241641 256000 up 96 0/96/0/96 (null)
community ccpu1-71 241525 256000 up 96 0/96/0/96 (null)
community ccpu1-72 241501 256000 up 96 0/96/0/96 (null)
community ccpu1-73 241527 256000 up 96 0/96/0/96 (null)
community ccpu1-74 241449 256000 up 96 0/96/0/96 (null)
community ccpu1-75 241604 256000 up 96 0/96/0/96 (null)
community ccpu1-76 241557 256000 up 96 0/96/0/96 (null)
community ccpu1-77 241587 256000 up 96 0/96/0/96 (null)
community ccpu1-78 241702 256000 up 96 0/96/0/96 (null)
community ccpu1-79 241540 256000 up 96 0/96/0/96 (null)
community ccpu1-80 241668 256000 up 96 0/96/0/96 (null)
community_short ccpu1-05 N/A 256000 up 96 0/0/96/96 (null)
community_short ccpu1-01 48704 256000 up 96 4/92/0/96 (null)
community_short ccpu1-02 155398 256000 up 96 0/96/0/96 (null)
community_short ccpu1-03 179667 256000 up 96 0/96/0/96 (null)
community_short ccpu1-04 191393 256000 up 96 0/96/0/96 (null)
community_short ccpu1-06 191620 256000 up 96 0/96/0/96 (null)
community_short ccpu1-07 176617 256000 up 96 0/96/0/96 (null)
community_short ccpu1-08 194720 256000 up 96 0/96/0/96 (null)
community_short ccpu1-09 193514 256000 up 96 0/96/0/96 (null)
community_short ccpu1-10 140249 256000 up 96 0/96/0/96 (null)
community_short ccpu1-11 200869 256000 up 96 0/96/0/96 (null)
community_short ccpu1-12 224064 256000 up 96 0/96/0/96 (null)
community_short ccpu1-13 225204 256000 up 96 0/96/0/96 (null)
community_short ccpu1-14 240278 256000 up 96 0/96/0/96 (null)
community_short ccpu1-15 236341 256000 up 96 0/96/0/96 (null)
community_short ccpu1-16 237111 256000 up 96 0/96/0/96 (null)
community_short ccpu1-17 237159 256000 up 96 0/96/0/96 (null)
community_short ccpu1-18 238948 256000 up 96 0/96/0/96 (null)
community_short ccpu1-19 241465 256000 up 96 0/96/0/96 (null)
community_short ccpu1-20 241553 256000 up 96 0/96/0/96 (null)
community_short ccpu1-21 241445 256000 up 96 0/96/0/96 (null)
community_short ccpu1-22 241563 256000 up 96 0/96/0/96 (null)
community_short ccpu1-23 241671 256000 up 96 0/96/0/96 (null)
community_short ccpu1-24 241628 256000 up 96 0/96/0/96 (null)
community_short ccpu1-25 241679 256000 up 96 0/96/0/96 (null)
community_short ccpu1-26 241540 256000 up 96 0/96/0/96 (null)
community_short ccpu1-27 241530 256000 up 96 0/96/0/96 (null)
community_short ccpu1-28 241571 256000 up 96 0/96/0/96 (null)
community_short ccpu1-29 241515 256000 up 96 0/96/0/96 (null)
community_short ccpu1-30 241493 256000 up 96 0/96/0/96 (null)
community_short ccpu1-31 241539 256000 up 96 0/96/0/96 (null)
community_short ccpu1-32 241629 256000 up 96 0/96/0/96 (null)
community_short ccpu1-33 241658 256000 up 96 0/96/0/96 (null)
community_short ccpu1-34 241671 256000 up 96 0/96/0/96 (null)
community_short ccpu1-35 241545 256000 up 96 0/96/0/96 (null)
community_short ccpu1-36 241675 256000 up 96 0/96/0/96 (null)
community_short ccpu1-37 241681 256000 up 96 0/96/0/96 (null)
community_short ccpu1-38 241494 256000 up 96 0/96/0/96 (null)
community_short ccpu1-39 241468 256000 up 96 0/96/0/96 (null)
community_short ccpu1-40 241491 256000 up 96 0/96/0/96 (null)
community_short ccpu1-41 241506 256000 up 96 0/96/0/96 (null)
community_short ccpu1-42 241521 256000 up 96 0/96/0/96 (null)
community_short ccpu1-43 241616 256000 up 96 0/96/0/96 (null)
community_short ccpu1-44 241454 256000 up 96 0/96/0/96 (null)
community_short ccpu1-45 241495 256000 up 96 0/96/0/96 (null)
community_short ccpu1-46 241552 256000 up 96 0/96/0/96 (null)
community_short ccpu1-47 241630 256000 up 96 0/96/0/96 (null)
community_short ccpu1-48 241459 256000 up 96 0/96/0/96 (null)
community_short ccpu1-49 241679 256000 up 96 0/96/0/96 (null)
community_short ccpu1-50 241434 256000 up 96 0/96/0/96 (null)
community_short ccpu1-51 241337 256000 up 96 0/96/0/96 (null)
community_short ccpu1-52 241524 256000 up 96 0/96/0/96 (null)
community_short ccpu1-53 241574 256000 up 96 0/96/0/96 (null)
community_short ccpu1-54 241668 256000 up 96 0/96/0/96 (null)
community_short ccpu1-55 241459 256000 up 96 0/96/0/96 (null)
community_short ccpu1-56 241490 256000 up 96 0/96/0/96 (null)
community_short ccpu1-57 241658 256000 up 96 0/96/0/96 (null)
community_short ccpu1-58 241483 256000 up 96 0/96/0/96 (null)
community_short ccpu1-59 241691 256000 up 96 0/96/0/96 (null)
community_short ccpu1-60 241629 256000 up 96 0/96/0/96 (null)
community_short ccpu1-61 241583 256000 up 96 0/96/0/96 (null)
community_short ccpu1-62 241513 256000 up 96 0/96/0/96 (null)
community_short ccpu1-63 241519 256000 up 96 0/96/0/96 (null)
community_short ccpu1-64 241597 256000 up 96 0/96/0/96 (null)
community_short ccpu1-65 241584 256000 up 96 0/96/0/96 (null)
community_short ccpu1-66 241500 256000 up 96 0/96/0/96 (null)
community_short ccpu1-67 241465 256000 up 96 0/96/0/96 (null)
community_short ccpu1-68 241431 256000 up 96 0/96/0/96 (null)
community_short ccpu1-69 241507 256000 up 96 0/96/0/96 (null)
community_short ccpu1-70 241641 256000 up 96 0/96/0/96 (null)
community_short ccpu1-71 241525 256000 up 96 0/96/0/96 (null)
community_short ccpu1-72 241501 256000 up 96 0/96/0/96 (null)
community_short ccpu1-73 241527 256000 up 96 0/96/0/96 (null)
community_short ccpu1-74 241449 256000 up 96 0/96/0/96 (null)
community_short ccpu1-75 241604 256000 up 96 0/96/0/96 (null)
community_short ccpu1-76 241557 256000 up 96 0/96/0/96 (null)
community_short ccpu1-77 241587 256000 up 96 0/96/0/96 (null)
community_short ccpu1-78 241702 256000 up 96 0/96/0/96 (null)
community_short ccpu1-79 241540 256000 up 96 0/96/0/96 (null)
community_short ccpu1-80 241668 256000 up 96 0/96/0/96 (null)
cpu* gcpu2-31 1526043 1540000 up 512 0/0/512/512 (null)
cpu* gcpu2-08 73439 1547000 up 336 60/276/0/336 (null)
cpu* gcpu2-03 309935 1547000 up 336 8/328/0/336 (null)
cpu* gcpu2-06 175170 1547000 up 336 46/290/0/336 (null)
cpu* gcpu2-07 179104 1547000 up 336 46/290/0/336 (null)
cpu* gcpu2-09 40223 1547000 up 336 50/286/0/336 (null)
cpu* gcpu2-10 240768 1547000 up 336 46/290/0/336 (null)
cpu* gcpu2-11 48679 1547000 up 336 54/282/0/336 (null)
cpu* gcpu2-12 16567 1547000 up 336 308/28/0/336 (null)
cpu* gcpu2-13 907252 1547000 up 336 200/136/0/336 (null)
cpu* gcpu2-14 483933 1547000 up 336 32/304/0/336 (null)
cpu* gcpu2-15 42951 1547000 up 336 46/290/0/336 (null)
cpu* gcpu2-16 16890 1547000 up 336 108/228/0/336 (null)
cpu* gcpu2-17 208672 1540000 up 512 18/494/0/512 (null)
cpu* gcpu2-18 167424 1540000 up 512 192/320/0/512 (null)
cpu* gcpu2-19 1082227 1540000 up 512 2/510/0/512 (null)
cpu* gcpu2-32 108456 1540000 up 512 50/462/0/512 (null)
cpu* gcpu2-33 223998 1540000 up 512 46/466/0/512 (null)
cpu* gcpu2-34 430285 1540000 up 512 96/416/0/512 (null)
cpu* gcpu2-04 180203 1547000 up 336 0/336/0/336 (null)
cpu* gcpu2-05 45402 1547000 up 336 0/336/0/336 (null)
cpu* gcpu2-20 723355 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-21 808344 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-22 1031324 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-23 1211988 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-24 559260 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-25 1360282 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-26 1416637 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-27 1441043 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-28 1351881 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-29 1525768 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-30 1085902 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-36 777848 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-37 902169 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-38 770896 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-39 957502 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-40 1525643 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-41 1525647 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-42 1525568 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-43 1525659 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-44 1525697 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-45 1525714 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-46 1525662 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-47 425079 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-48 529699 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-55 496345 1540000 up 512 0/512/0/512 (null)
cpu* gcpu2-35 1525781 1540000 up 512 0/0/512/512 (null)
gpu ggpu1-07 27750 386000 up 64 4/60/0/64 gpu:nvidia_l40s:2
gpu ggpu1-08 5235 386000 up 64 16/48/0/64 gpu:nvidia_l40s:2
gpu ggpu1-09 27394 386000 up 64 10/54/0/64 gpu:nvidia_l40s:2
gpu ggpu1-10 21461 386000 up 64 16/48/0/64 gpu:nvidia_l40s:2
gpu ggpu1-11 18659 386000 up 64 10/54/0/64 gpu:nvidia_l40s:2
gpu ggpu1-14 2767 380000 up 128 24/104/0/128 gpu:nvidia_rtx_pro_6000:2
gpu ggpu1-16 67431 380000 up 128 18/110/0/128 gpu:nvidia_rtx_pro_6000:2
gpu ggpu1-17 52835 380000 up 128 100/28/0/128 gpu:nvidia_rtx_pro_6000:2
gpu ggpu4-01 21305 386000 up 64 32/32/0/64 gpu:nvidia_h100_nvl:1(S:0)
gpu ggpu4-02 16332 386000 up 64 2/62/0/64 gpu:nvidia_h100_nvl:1(S:0)
gpu ggpu4-03 4966 386000 up 64 4/60/0/64 gpu:nvidia_h100_nvl:1(S:0)
gpu ggpu4-04 16149 386000 up 64 2/62/0/64 gpu:nvidia_h100_nvl:1(S:0)
gpu ggpu4-06 18971 386000 up 64 40/24/0/64 gpu:nvidia_h100_nvl:1(S:0)
gpu ggpu1-06 4704 386000 up 64 20/44/0/64 gpu:nvidia_l40s:2
gpu ggpu1-12 16843 386000 up 64 32/32/0/64 gpu:nvidia_l40s:2
gpu ggpu1-13 4706 380000 up 128 100/28/0/128 gpu:nvidia_rtx_pro_6000:2
gpu ggpu1-15 100696 380000 up 128 16/112/0/128 gpu:nvidia_rtx_pro_6000:2
gpu ggpu1-18 48776 380000 up 128 100/28/0/128 gpu:nvidia_rtx_pro_6000:2
gpu ggpu1-19 161490 380000 up 128 100/28/0/128 gpu:nvidia_rtx_pro_6000:2
gpu ggpu4-05 25195 386000 up 64 60/4/0/64 gpu:nvidia_h100_nvl:1(S:0)
large_gpu ggpu3-17 146930 2060000 up 240 226/14/0/240 gpu:nvidia_h200:8
large_gpu ggpu3-18 239802 2060000 up 240 212/28/0/240 gpu:nvidia_h200:8
large_gpu ggpu3-19 492808 2060000 up 240 40/200/0/240 gpu:nvidia_h200:8
large_gpu ggpu3-23 835138 2060000 up 208 96/112/0/208 gpu:nvidia_h200:8
large_gpu ggpu3-26 653150 2060000 up 208 198/10/0/208 gpu:nvidia_h200:8
large_gpu ggpu3-28 110118 2060000 up 208 184/24/0/208 gpu:nvidia_h200:8
large_gpu ggpu5-01 1005771 1540000 up 256 106/150/0/256 gpu:nvidia_h200_nvl:4
large_gpu ggpu3-20 221031 2060000 up 240 240/0/0/240 gpu:nvidia_h200:8
large_gpu ggpu3-21 112741 2060000 up 208 208/0/0/208 gpu:nvidia_h200:8
large_gpu ggpu3-22 609824 2060000 up 208 208/0/0/208 gpu:nvidia_h200:8
large_gpu ggpu3-24 84213 2060000 up 208 208/0/0/208 gpu:nvidia_h200:8
large_gpu ggpu3-25 73012 2060000 up 208 208/0/0/208 gpu:nvidia_h200:8
large_gpu ggpu3-29 98534 2060000 up 208 208/0/0/208 gpu:nvidia_h200:8
large_gpu ggpu3-27 253748 2060000 up 208 0/208/0/208 gpu:nvidia_h200:8
large_gpu ggpu5-02 1273014 1540000 up 256 0/256/0/256 gpu:nvidia_h200_nvl:4
large_gpu ggpu5-03 1395238 1540000 up 256 0/256/0/256 gpu:nvidia_h200_nvl:4
pod ggpu3-09 42212 2063700 up 208 130/78/0/208 gpu:nvidia_h200:8
pod ggpu3-12 76364 2063700 up 208 200/8/0/208 gpu:nvidia_h200:8
pod ggpu3-13 51884 2063700 up 208 40/168/0/208 gpu:nvidia_h200:8
pod ggpu3-15 117134 2063700 up 208 60/148/0/208 gpu:nvidia_h200:8
pod ggpu3-10 52032 2063700 up 208 200/8/0/208 gpu:nvidia_h200:8
pod ggpu3-11 210501 2063700 up 208 52/156/0/208 gpu:nvidia_h200:8
pod ggpu3-14 772844 2063700 up 208 200/8/0/208 gpu:nvidia_h200:8
pod ggpu3-16 508018 2063700 up 208 200/8/0/208 gpu:nvidia_h200:8
```

## Partition config (scontrol)

```
PartitionName=community
   AllowGroups=ALL AllowAccounts=ALL AllowQos=hpc_core,cmnt,sali_lab_qos,plenum
   AllocNodes=ALL Default=NO QoS=cmnt
   DefaultTime=01:00:00 DisableRootJobs=NO ExclusiveUser=NO ExclusiveTopo=NO GraceTime=0 Hidden=NO
   MaxNodes=UNLIMITED MaxTime=14-00:00:00 MinNodes=0 LLN=NO MaxCPUsPerNode=UNLIMITED MaxCPUsPerSocket=UNLIMITED
   Nodes=ccpu1-[01-80]
   PriorityJobFactor=1 PriorityTier=1 RootOnly=NO ReqResv=NO OverSubscribe=NO
   OverTimeLimit=NONE PreemptMode=OFF
   State=UP TotalCPUs=7680 TotalNodes=80 SelectTypeParameters=NONE
   JobDefaults=(null)
   DefMemPerCPU=4096 MaxMemPerNode=UNLIMITED
   TRES=cpu=7680,mem=20000G,node=80,billing=7680

PartitionName=community_short
   AllowGroups=ALL AllowAccounts=ALL AllowQos=cmnt_short,sali_lab_qos,plenum
   AllocNodes=ALL Default=NO QoS=cmnt_short
   DefaultTime=01:00:00 DisableRootJobs=NO ExclusiveUser=NO ExclusiveTopo=NO GraceTime=0 Hidden=NO
   MaxNodes=UNLIMITED MaxTime=01:00:00 MinNodes=0 LLN=NO MaxCPUsPerNode=UNLIMITED MaxCPUsPerSocket=UNLIMITED
   Nodes=ccpu1-[01-80]
   PriorityJobFactor=1 PriorityTier=1 RootOnly=NO ReqResv=NO OverSubscribe=NO
   OverTimeLimit=NONE PreemptMode=OFF
   State=UP TotalCPUs=7680 TotalNodes=80 SelectTypeParameters=NONE
   JobDefaults=(null)
   DefMemPerCPU=4096 MaxMemPerNode=UNLIMITED
   TRES=cpu=7680,mem=20000G,node=80,billing=7680

PartitionName=cpu
   AllowGroups=ALL AllowAccounts=ALL AllowQos=hpc_core,cpu,high_cpu,plenum
   AllocNodes=ALL Default=YES QoS=cpu
   DefaultTime=01:00:00 DisableRootJobs=NO ExclusiveUser=NO ExclusiveTopo=NO GraceTime=0 Hidden=NO
   MaxNodes=UNLIMITED MaxTime=4-00:00:00 MinNodes=0 LLN=NO MaxCPUsPerNode=UNLIMITED MaxCPUsPerSocket=UNLIMITED
   Nodes=gcpu2-[03-48,55]
   PriorityJobFactor=1 PriorityTier=1 RootOnly=NO ReqResv=NO OverSubscribe=NO
   OverTimeLimit=NONE PreemptMode=OFF
   State=UP TotalCPUs=21600 TotalNodes=47 SelectTypeParameters=NONE
   JobDefaults=(null)
   DefMemPerCPU=4096 MaxMemPerNode=UNLIMITED
   TRES=cpu=21600,mem=72478000M,node=47,billing=21600

PartitionName=gpu
   AllowGroups=ALL AllowAccounts=ALL AllowQos=hpc_core,gpu,high_gpu,plenum
   AllocNodes=ALL Default=NO QoS=gpu
   DefaultTime=01:00:00 DisableRootJobs=NO ExclusiveUser=NO ExclusiveTopo=NO GraceTime=0 Hidden=NO
   MaxNodes=UNLIMITED MaxTime=4-00:00:00 MinNodes=0 LLN=NO MaxCPUsPerNode=UNLIMITED MaxCPUsPerSocket=UNLIMITED
   Nodes=ggpu1-[06-19],ggpu4-[01-06]
   PriorityJobFactor=1 PriorityTier=1 RootOnly=NO ReqResv=NO OverSubscribe=NO
   OverTimeLimit=NONE PreemptMode=OFF
   State=UP TotalCPUs=1728 TotalNodes=20 SelectTypeParameters=NONE
   JobDefaults=DefCpuPerGPU=32
   DefMemPerCPU=6144 MaxMemPerNode=UNLIMITED
   TRES=cpu=1728,mem=7678000M,node=20,billing=1728,gres/gpu=34,gres/gpu:nvidia_h100_nvl=6,gres/gpu:nvidia_l40s=14

PartitionName=large_gpu
   AllowGroups=ALL AllowAccounts=ucsf_neurosurgery,ucsf_kortemme,ucsf_yang,ucsf_admins AllowQos=neurosurgery_qos,kortemme_lab_qos,yang_lab_qos,large_gpu,plenum
   AllocNodes=ALL Default=NO QoS=large_gpu
   DefaultTime=01:00:00 DisableRootJobs=NO ExclusiveUser=NO ExclusiveTopo=NO GraceTime=0 Hidden=NO
   MaxNodes=UNLIMITED MaxTime=1-00:00:00 MinNodes=0 LLN=NO MaxCPUsPerNode=UNLIMITED MaxCPUsPerSocket=UNLIMITED
   Nodes=ggpu3-[17-29],ggpu5-[01-03]
   PriorityJobFactor=1 PriorityTier=1 RootOnly=NO ReqResv=NO OverSubscribe=NO
   OverTimeLimit=NONE PreemptMode=OFF
   State=UP TotalCPUs=3600 TotalNodes=16 SelectTypeParameters=NONE
   JobDefaults=DefCpuPerGPU=25
   DefMemPerCPU=6144 MaxMemPerNode=UNLIMITED
   TRES=cpu=3600,mem=31400000M,node=16,billing=3600,gres/gpu=116,gres/gpu:nvidia_h200=104

PartitionName=pod
   AllowGroups=ALL AllowAccounts=ucsf_pod,ucsf_high_pod,ucsf_admins AllowQos=pod,high_pod,plenum
   AllocNodes=ALL Default=NO QoS=pod
   DefaultTime=01:00:00 DisableRootJobs=NO ExclusiveUser=NO ExclusiveTopo=NO GraceTime=0 Hidden=NO
   MaxNodes=UNLIMITED MaxTime=4-00:00:00 MinNodes=0 LLN=NO MaxCPUsPerNode=UNLIMITED MaxCPUsPerSocket=UNLIMITED
   Nodes=ggpu3-[09-16]
   PriorityJobFactor=1 PriorityTier=1 RootOnly=NO ReqResv=NO OverSubscribe=NO
   OverTimeLimit=NONE PreemptMode=OFF
   State=UP TotalCPUs=1664 TotalNodes=8 SelectTypeParameters=NONE
   JobDefaults=DefCpuPerGPU=32
   DefMemPerCPU=6144 MaxMemPerNode=UNLIMITED
   TRES=cpu=1664,mem=16509600M,node=8,billing=1664,gres/gpu=64,gres/gpu:nvidia_h200=64

```

## QoS

```
Name|Priority|MaxWall|MaxTRESPU|MaxJobsPU|MaxSubmitPU|GrpTRES
normal|0|||||
hpc_core|0|||||
plenum|0|7-00:00:00|cpu=99999,gres/gpu=999,node=999|99999||
pod|0||node=2|2||
cpu|0||cpu=2048,node=8|||
gpu|0||gres/gpu:nvidia_h100_nvl=8,gres/gpu:nvidia_h200=8,gres/gpu:nvidia_l40s=8,gres/gpu=8|21||
large_gpu|0|||||
kortemme_lab_qos|1|7-00:00:00|gres/gpu=4,node=3|3||
sali_lab_qos|1|||||
cmnt|0||cpu=768,node=8|||
cmnt_short|0||node=1|||
neurosurgery_qos|1|7-00:00:00||2400||cpu=2400,gres/gpu=96,mem=24720000M,node=12
high_cpu|0|7-00:00:00|cpu=2048,node=8|8||
high_gpu|1||gres/gpu=8|8||
high_pod|1|7-00:00:00|cpu=2048,node=2|2||
yang_lab_qos|1|7-00:00:00||208||cpu=208,gres/gpu=8,mem=2060000M,node=1
```

## My associations (accounts/QoS I can use)

```
Cluster|Account|Partition|QOS|MaxJobs|MaxSubmit
ucsf|hpc_core||cmnt,cmnt_short,cpu,gpu,hpc_core||
```

## GRES types

```
gpu:nvidia_h100_nvl:1(S:0)
gpu:nvidia_h200:8
gpu:nvidia_h200_nvl:4
gpu:nvidia_l40s:2
gpu:nvidia_rtx_pro_6000:2
GRES
(null)
```

## Storage: mounts

```
Filesystem                       Type  Size  Used Avail Use% Mounted on
ucsf.vast.corehpc.ucsf.edu:/home nfs   2.3P  8.2T  2.3P   1% /home/remote
Filesystem                          Type  Size  Used Avail Use% Mounted on
ucsf.vast.corehpc.ucsf.edu:/scratch nfs   2.3P  499T  1.8P  22% /mnt/scratch
Filesystem                          Type  Size  Used Avail Use% Mounted on
fac-ha.fac.corehpc.ucsf.edu:/export nfs4   49G   23G   24G  50% /mnt/fac
systemd-1 on /mnt/scratch type autofs (rw,relatime,fd=58,pgrp=1,timeout=600,minproto=5,maxproto=5,direct,pipe_ino=32883)
ucsf.vast.corehpc.ucsf.edu:/home on /mnt/home type nfs (rw,noatime,vers=3,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,nconnect=16,timeo=600,retrans=2,sec=sys,mountaddr=10.98.63.11,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.98.63.11,_netdev)
ucsf.vast.corehpc.ucsf.edu:/home on /home/remote type nfs (rw,noatime,vers=3,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,nconnect=16,timeo=600,retrans=2,sec=sys,mountaddr=10.98.63.11,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.98.63.11,_netdev)
ucsf.vast.corehpc.ucsf.edu:/scratch on /mnt/scratch type nfs (rw,noatime,vers=3,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,nconnect=16,timeo=600,retrans=2,sec=sys,mountaddr=10.98.63.1,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.98.63.1,_netdev)
ucsf-shared.vast.corehpc.ucsf.edu:/shared_admin on /mnt/admin type nfs (rw,noatime,vers=3,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,mountaddr=10.98.63.21,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.98.63.21,_netdev)
systemd-1 on /mnt/fac type autofs (rw,relatime,fd=76,pgrp=1,timeout=600,minproto=5,maxproto=5,direct,pipe_ino=112139644)
fac-ha.fac.corehpc.ucsf.edu:/export on /mnt/fac type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102,_netdev)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500035_DS7 on /mnt/fac/CX500035_DS7 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000055_DS1 on /mnt/fac/CX000055_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000018_DS2 on /mnt/fac/CX000018_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500073_DS1 on /mnt/fac/CX500073_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500074_DS1 on /mnt/fac/CX500074_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500007_DS2 on /mnt/fac/CX500007_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500001_DS2 on /mnt/fac/CX500001_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000018_DS3 on /mnt/fac/CX000018_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500118_DS2 on /mnt/fac/CX500118_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000019_DS2 on /mnt/fac/CX000019_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500057_DS1 on /mnt/fac/CX500057_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500008_DS1 on /mnt/fac/CX500008_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000023_DS3 on /mnt/fac/CX000023_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000023_DS5 on /mnt/fac/CX000023_DS5 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500124_DS2 on /mnt/fac/CX500124_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500013_DS2 on /mnt/fac/CX500013_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500129_DS1 on /mnt/fac/CX500129_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500136_DS1 on /mnt/fac/CX500136_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500026_DS1 on /mnt/fac/CX500026_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500053_DS1 on /mnt/fac/CX500053_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000026_DS1 on /mnt/fac/CX000026_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500012_DS1 on /mnt/fac/CX500012_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500024_DS2 on /mnt/fac/CX500024_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000018_DS1 on /mnt/fac/CX000018_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500024_DS1 on /mnt/fac/CX500024_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000033_DS1 on /mnt/fac/CX000033_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500059_DS1 on /mnt/fac/CX500059_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000068_DS1 on /mnt/fac/CX000068_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000056_DS1 on /mnt/fac/CX000056_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000019_DS1 on /mnt/fac/CX000019_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500117_DS1 on /mnt/fac/CX500117_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000056_DS3 on /mnt/fac/CX000056_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500106_DS1 on /mnt/fac/CX500106_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS1 on /mnt/fac/CX900004_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS150 on /mnt/fac/CX900004_DS150 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS121 on /mnt/fac/CX900004_DS121 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS12 on /mnt/fac/CX900004_DS12 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS2 on /mnt/fac/CX900004_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000062_DS1 on /mnt/fac/CX000062_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS129 on /mnt/fac/CX900004_DS129 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500013_DS1 on /mnt/fac/CX500013_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500009_DS2 on /mnt/fac/CX500009_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS20 on /mnt/fac/CX900004_DS20 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500022_DS1 on /mnt/fac/CX500022_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500002_DS4 on /mnt/fac/CX500002_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500097_DS1 on /mnt/fac/CX500097_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500009_DS4 on /mnt/fac/CX500009_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000070_DS2 on /mnt/fac/CX000070_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS72 on /mnt/fac/CX900004_DS72 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500083_DS1 on /mnt/fac/CX500083_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500055_DS5 on /mnt/fac/CX500055_DS5 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000059_DS1 on /mnt/fac/CX000059_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS66 on /mnt/fac/CX900004_DS66 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500070_DS1 on /mnt/fac/CX500070_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS131 on /mnt/fac/CX900004_DS131 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500019_DS1 on /mnt/fac/CX500019_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000013_DS1 on /mnt/fac/CX000013_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS2 on /mnt/fac/CX500036_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500095_DS1 on /mnt/fac/CX500095_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500011_DS3 on /mnt/fac/CX500011_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS18 on /mnt/fac/CX500036_DS18 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500002_DS2 on /mnt/fac/CX500002_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900003_DS1 on /mnt/fac/CX900003_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500009_DS1 on /mnt/fac/CX500009_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS139 on /mnt/fac/CX900004_DS139 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500147_DS2 on /mnt/fac/CX500147_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS11 on /mnt/fac/CX900004_DS11 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS7 on /mnt/fac/CX500021_DS7 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500044_DS2 on /mnt/fac/CX500044_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500114_DS1 on /mnt/fac/CX500114_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500107_DS1 on /mnt/fac/CX500107_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500033_DS1 on /mnt/fac/CX500033_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000054_DS1 on /mnt/fac/CX000054_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500043_DS4 on /mnt/fac/CX500043_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500142_DS1 on /mnt/fac/CX500142_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS9 on /mnt/fac/CX500021_DS9 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500001_DS1 on /mnt/fac/CX500001_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500126_DS1 on /mnt/fac/CX500126_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS117 on /mnt/fac/CX900004_DS117 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500005_DS1 on /mnt/fac/CX500005_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000010_DS6 on /mnt/fac/CX000010_DS6 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500137_DS1 on /mnt/fac/CX500137_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000037_DS1 on /mnt/fac/CX000037_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS115 on /mnt/fac/CX900004_DS115 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500011_DS1 on /mnt/fac/CX500011_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX800001_DS2 on /mnt/fac/CX800001_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500008_DS2 on /mnt/fac/CX500008_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500009_DS3 on /mnt/fac/CX500009_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900005_DS3 on /mnt/fac/CX900005_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000030_DS2 on /mnt/fac/CX000030_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500035_DS6 on /mnt/fac/CX500035_DS6 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500017_DS3 on /mnt/fac/CX500017_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS9 on /mnt/fac/CX500036_DS9 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500011_DS7 on /mnt/fac/CX500011_DS7 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900005_DS6 on /mnt/fac/CX900005_DS6 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500043_DS2 on /mnt/fac/CX500043_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500029_DS1 on /mnt/fac/CX500029_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500090_DS1 on /mnt/fac/CX500090_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500040_DS7 on /mnt/fac/CX500040_DS7 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500020_DS1 on /mnt/fac/CX500020_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500041_DS1 on /mnt/fac/CX500041_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900005_DS1 on /mnt/fac/CX900005_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS41 on /mnt/fac/CX900004_DS41 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS134 on /mnt/fac/CX900004_DS134 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS16 on /mnt/fac/CX500036_DS16 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500125_DS1 on /mnt/fac/CX500125_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900001_DS5 on /mnt/fac/CX900001_DS5 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS42 on /mnt/fac/CX900004_DS42 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000033_DS2 on /mnt/fac/CX000033_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500050_DS2 on /mnt/fac/CX500050_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS5 on /mnt/fac/CX900004_DS5 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500022_DS3 on /mnt/fac/CX500022_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS10 on /mnt/fac/CX900004_DS10 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS61 on /mnt/fac/CX900004_DS61 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS11 on /mnt/fac/CX500021_DS11 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500011_DS2 on /mnt/fac/CX500011_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS114 on /mnt/fac/CX900004_DS114 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500134_DS1 on /mnt/fac/CX500134_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500081_DS1 on /mnt/fac/CX500081_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500017_DS2 on /mnt/fac/CX500017_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500101_DS1 on /mnt/fac/CX500101_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS4 on /mnt/fac/CX500036_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS6 on /mnt/fac/CX500036_DS6 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS135 on /mnt/fac/CX900004_DS135 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS13 on /mnt/fac/CX900004_DS13 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500087_DS1 on /mnt/fac/CX500087_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS152 on /mnt/fac/CX900004_DS152 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000013_DS2 on /mnt/fac/CX000013_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500089_DS1 on /mnt/fac/CX500089_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500043_DS1 on /mnt/fac/CX500043_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000050_DS1 on /mnt/fac/CX000050_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS91 on /mnt/fac/CX900004_DS91 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000067_DS4 on /mnt/fac/CX000067_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500002_DS5 on /mnt/fac/CX500002_DS5 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS125 on /mnt/fac/CX900004_DS125 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500061_DS1 on /mnt/fac/CX500061_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500011_DS5 on /mnt/fac/CX500011_DS5 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500006_DS4 on /mnt/fac/CX500006_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500055_DS2 on /mnt/fac/CX500055_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS2 on /mnt/fac/CX500021_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500141_DS1 on /mnt/fac/CX500141_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500055_DS1 on /mnt/fac/CX500055_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS1 on /mnt/fac/CX500036_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS101 on /mnt/fac/CX900004_DS101 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS13 on /mnt/fac/CX500036_DS13 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000047_DS1 on /mnt/fac/CX000047_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500066_DS1 on /mnt/fac/CX500066_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500025_DS2 on /mnt/fac/CX500025_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500147_DS1 on /mnt/fac/CX500147_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500082_DS1 on /mnt/fac/CX500082_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS89 on /mnt/fac/CX900004_DS89 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500050_DS1 on /mnt/fac/CX500050_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS5 on /mnt/fac/CX500036_DS5 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS100 on /mnt/fac/CX900004_DS100 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS64 on /mnt/fac/CX900004_DS64 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS17 on /mnt/fac/CX900004_DS17 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS113 on /mnt/fac/CX900004_DS113 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS98 on /mnt/fac/CX900004_DS98 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500069_DS2 on /mnt/fac/CX500069_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500055_DS4 on /mnt/fac/CX500055_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500003_DS1 on /mnt/fac/CX500003_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS12 on /mnt/fac/CX500021_DS12 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS145 on /mnt/fac/CX900004_DS145 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900005_DS2 on /mnt/fac/CX900005_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500102_DS2 on /mnt/fac/CX500102_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500063_DS1 on /mnt/fac/CX500063_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900007_DS1 on /mnt/fac/CX900007_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS4 on /mnt/fac/CX900004_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000040_DS1 on /mnt/fac/CX000040_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS116 on /mnt/fac/CX900004_DS116 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500149_DS1 on /mnt/fac/CX500149_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500054_DS1 on /mnt/fac/CX500054_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS143 on /mnt/fac/CX900004_DS143 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS147 on /mnt/fac/CX900004_DS147 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000024_DS3 on /mnt/fac/CX000024_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500091_DS1 on /mnt/fac/CX500091_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000032_DS2 on /mnt/fac/CX000032_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500039_DS1 on /mnt/fac/CX500039_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500098_DS2 on /mnt/fac/CX500098_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS82 on /mnt/fac/CX900004_DS82 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS15 on /mnt/fac/CX500021_DS15 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS122 on /mnt/fac/CX900004_DS122 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900005_DS5 on /mnt/fac/CX900005_DS5 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS3 on /mnt/fac/CX500021_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS67 on /mnt/fac/CX900004_DS67 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500028_DS2 on /mnt/fac/CX500028_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS13 on /mnt/fac/CX500021_DS13 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500094_DS1 on /mnt/fac/CX500094_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500011_DS6 on /mnt/fac/CX500011_DS6 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS69 on /mnt/fac/CX900004_DS69 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS3 on /mnt/fac/CX500036_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900005_DS4 on /mnt/fac/CX900005_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500040_DS10 on /mnt/fac/CX500040_DS10 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS3 on /mnt/fac/CX900004_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500139_DS1 on /mnt/fac/CX500139_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500026_DS2 on /mnt/fac/CX500026_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000048_DS1 on /mnt/fac/CX000048_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500062_DS3 on /mnt/fac/CX500062_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500014_DS2 on /mnt/fac/CX500014_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS137 on /mnt/fac/CX900004_DS137 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS17 on /mnt/fac/CX500036_DS17 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500022_DS2 on /mnt/fac/CX500022_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500144_DS1 on /mnt/fac/CX500144_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500009_DS10 on /mnt/fac/CX500009_DS10 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000039_DS3 on /mnt/fac/CX000039_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS99 on /mnt/fac/CX900004_DS99 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS10 on /mnt/fac/CX500036_DS10 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000057_DS1 on /mnt/fac/CX000057_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500085_DS1 on /mnt/fac/CX500085_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500023_DS1 on /mnt/fac/CX500023_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS8 on /mnt/fac/CX500036_DS8 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500133_DS1 on /mnt/fac/CX500133_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000003_DS3 on /mnt/fac/CX000003_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500009_DS8 on /mnt/fac/CX500009_DS8 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500102_DS1 on /mnt/fac/CX500102_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS7 on /mnt/fac/CX500036_DS7 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500009_DS5 on /mnt/fac/CX500009_DS5 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500004_DS2 on /mnt/fac/CX500004_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS4 on /mnt/fac/CX500021_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500018_DS2 on /mnt/fac/CX500018_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000014_DS2 on /mnt/fac/CX000014_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500148_DS1 on /mnt/fac/CX500148_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500042_DS1 on /mnt/fac/CX500042_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS46 on /mnt/fac/CX900004_DS46 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500013_DS3 on /mnt/fac/CX500013_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500065_DS1 on /mnt/fac/CX500065_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500032_DS2 on /mnt/fac/CX500032_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000010_DS10 on /mnt/fac/CX000010_DS10 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500118_DS1 on /mnt/fac/CX500118_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS14 on /mnt/fac/CX500036_DS14 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000010_DS7 on /mnt/fac/CX000010_DS7 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS49 on /mnt/fac/CX900004_DS49 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500040_DS4 on /mnt/fac/CX500040_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500138_DS1 on /mnt/fac/CX500138_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS86 on /mnt/fac/CX900004_DS86 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500007_DS1 on /mnt/fac/CX500007_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500064_DS1 on /mnt/fac/CX500064_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500028_DS1 on /mnt/fac/CX500028_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS62 on /mnt/fac/CX900004_DS62 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS8 on /mnt/fac/CX900004_DS8 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500135_DS1 on /mnt/fac/CX500135_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500044_DS1 on /mnt/fac/CX500044_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS15 on /mnt/fac/CX500036_DS15 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000041_DS1 on /mnt/fac/CX000041_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000061_DS1 on /mnt/fac/CX000061_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500027_DS1 on /mnt/fac/CX500027_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500035_DS4 on /mnt/fac/CX500035_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000023_DS1 on /mnt/fac/CX000023_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500040_DS3 on /mnt/fac/CX500040_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500092_DS1 on /mnt/fac/CX500092_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000033_DS3 on /mnt/fac/CX000033_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000023_DS4 on /mnt/fac/CX000023_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000044_DS1 on /mnt/fac/CX000044_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000042_DS2 on /mnt/fac/CX000042_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500034_DS1 on /mnt/fac/CX500034_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500015_DS1 on /mnt/fac/CX500015_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500071_DS1 on /mnt/fac/CX500071_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS102 on /mnt/fac/CX900004_DS102 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500020_DS2 on /mnt/fac/CX500020_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500038_DS1 on /mnt/fac/CX500038_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS56 on /mnt/fac/CX900004_DS56 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS79 on /mnt/fac/CX900004_DS79 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000058_DS1 on /mnt/fac/CX000058_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS103 on /mnt/fac/CX900004_DS103 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS132 on /mnt/fac/CX900004_DS132 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000041_DS2 on /mnt/fac/CX000041_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500093_DS1 on /mnt/fac/CX500093_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500068_DS1 on /mnt/fac/CX500068_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS73 on /mnt/fac/CX900004_DS73 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500010_DS1 on /mnt/fac/CX500010_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS50 on /mnt/fac/CX900004_DS50 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS63 on /mnt/fac/CX900004_DS63 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS57 on /mnt/fac/CX900004_DS57 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000042_DS1 on /mnt/fac/CX000042_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000046_DS1 on /mnt/fac/CX000046_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500143_DS1 on /mnt/fac/CX500143_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS5 on /mnt/fac/CX500021_DS5 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500043_DS5 on /mnt/fac/CX500043_DS5 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500031_DS1 on /mnt/fac/CX500031_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000039_DS1 on /mnt/fac/CX000039_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500052_DS1 on /mnt/fac/CX500052_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500075_DS1 on /mnt/fac/CX500075_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS136 on /mnt/fac/CX900004_DS136 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000063_DS2 on /mnt/fac/CX000063_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500040_DS2 on /mnt/fac/CX500040_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS11 on /mnt/fac/CX500036_DS11 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500002_DS1 on /mnt/fac/CX500002_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS148 on /mnt/fac/CX900004_DS148 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS33 on /mnt/fac/CX900004_DS33 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500141_DS2 on /mnt/fac/CX500141_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS8 on /mnt/fac/CX500021_DS8 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000035_DS1 on /mnt/fac/CX000035_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS130 on /mnt/fac/CX900004_DS130 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS71 on /mnt/fac/CX900004_DS71 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS124 on /mnt/fac/CX900004_DS124 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS119 on /mnt/fac/CX900004_DS119 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000056_DS2 on /mnt/fac/CX000056_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500006_DS3 on /mnt/fac/CX500006_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000038_DS3 on /mnt/fac/CX000038_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500006_DS2 on /mnt/fac/CX500006_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS133 on /mnt/fac/CX900004_DS133 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500067_DS1 on /mnt/fac/CX500067_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS9 on /mnt/fac/CX900004_DS9 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500078_DS1 on /mnt/fac/CX500078_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS128 on /mnt/fac/CX900004_DS128 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS126 on /mnt/fac/CX900004_DS126 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000043_DS1 on /mnt/fac/CX000043_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500035_DS3 on /mnt/fac/CX500035_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500131_DS1 on /mnt/fac/CX500131_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500025_DS1 on /mnt/fac/CX500025_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS78 on /mnt/fac/CX900004_DS78 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500072_DS1 on /mnt/fac/CX500072_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500036_DS12 on /mnt/fac/CX500036_DS12 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500099_DS1 on /mnt/fac/CX500099_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS118 on /mnt/fac/CX900004_DS118 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500079_DS1 on /mnt/fac/CX500079_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500146_DS1 on /mnt/fac/CX500146_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500130_DS1 on /mnt/fac/CX500130_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500016_DS1 on /mnt/fac/CX500016_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500035_DS2 on /mnt/fac/CX500035_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500090_DS2 on /mnt/fac/CX500090_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500002_DS6 on /mnt/fac/CX500002_DS6 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000066_DS1 on /mnt/fac/CX000066_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500040_DS1 on /mnt/fac/CX500040_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500017_DS1 on /mnt/fac/CX500017_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500037_DS3 on /mnt/fac/CX500037_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500145_DS1 on /mnt/fac/CX500145_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS127 on /mnt/fac/CX900004_DS127 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000011_DS1 on /mnt/fac/CX000011_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000027_DS1 on /mnt/fac/CX000027_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500043_DS3 on /mnt/fac/CX500043_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500014_DS1 on /mnt/fac/CX500014_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000030_DS1 on /mnt/fac/CX000030_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500077_DS1 on /mnt/fac/CX500077_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500040_DS9 on /mnt/fac/CX500040_DS9 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500104_DS1 on /mnt/fac/CX500104_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500069_DS1 on /mnt/fac/CX500069_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500041_DS3 on /mnt/fac/CX500041_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500030_DS1 on /mnt/fac/CX500030_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500009_DS6 on /mnt/fac/CX500009_DS6 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500040_DS8 on /mnt/fac/CX500040_DS8 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000065_DS1 on /mnt/fac/CX000065_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500116_DS1 on /mnt/fac/CX500116_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000071_DS1 on /mnt/fac/CX000071_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000039_DS2 on /mnt/fac/CX000039_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS93 on /mnt/fac/CX900004_DS93 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000023_DS2 on /mnt/fac/CX000023_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500098_DS1 on /mnt/fac/CX500098_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS25 on /mnt/fac/CX900004_DS25 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS10 on /mnt/fac/CX500021_DS10 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS6 on /mnt/fac/CX900004_DS6 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500109_DS1 on /mnt/fac/CX500109_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500021_DS6 on /mnt/fac/CX500021_DS6 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000038_DS2 on /mnt/fac/CX000038_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500040_DS5 on /mnt/fac/CX500040_DS5 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500009_DS9 on /mnt/fac/CX500009_DS9 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS120 on /mnt/fac/CX900004_DS120 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500103_DS1 on /mnt/fac/CX500103_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500011_DS4 on /mnt/fac/CX500011_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500108_DS1 on /mnt/fac/CX500108_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500084_DS1 on /mnt/fac/CX500084_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500088_DS1 on /mnt/fac/CX500088_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500032_DS1 on /mnt/fac/CX500032_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS14 on /mnt/fac/CX900004_DS14 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500076_DS1 on /mnt/fac/CX500076_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000064_DS1 on /mnt/fac/CX000064_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500032_DS3 on /mnt/fac/CX500032_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500151_DS1 on /mnt/fac/CX500151_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500086_DS1 on /mnt/fac/CX500086_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500037_DS1 on /mnt/fac/CX500037_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000031_DS1 on /mnt/fac/CX000031_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500132_DS1 on /mnt/fac/CX500132_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500009_DS7 on /mnt/fac/CX500009_DS7 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500055_DS3 on /mnt/fac/CX500055_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000034_DS1 on /mnt/fac/CX000034_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX800001_DS1 on /mnt/fac/CX800001_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX000049_DS1 on /mnt/fac/CX000049_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS36 on /mnt/fac/CX900004_DS36 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900005_DS7 on /mnt/fac/CX900005_DS7 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500017_DS4 on /mnt/fac/CX500017_DS4 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500033_DS2 on /mnt/fac/CX500033_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500035_DS1 on /mnt/fac/CX500035_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500060_DS1 on /mnt/fac/CX500060_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500041_DS2 on /mnt/fac/CX500041_DS2 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500002_DS3 on /mnt/fac/CX500002_DS3 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX900004_DS21 on /mnt/fac/CX900004_DS21 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
fac-ha.fac.corehpc.ucsf.edu:/export/CX500006_DS1 on /mnt/fac/CX500006_DS1 type nfs4 (rw,noatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,softreval,proto=tcp,nconnect=12,timeo=600,retrans=2,sec=sys,clientaddr=10.98.64.29,local_lock=none,addr=10.98.70.102)
```

## Storage: my quota (userquota)

```
user: kanderson6 (uid 1631829934)

  Filesystem                            Used      Soft      Hard      Use%    |  Status
  ucsf.vast.corehpc.ucsf.edu:/scratch   36 MiB    49 TiB    50 TiB    0%      |  OK
  ucsf.vast.corehpc.ucsf.edu:/home      8 KiB     19 GiB    20 GiB    0%      |  OK

```

## Storage: FAC shares I belong to

```
total 5986
drwxrwx---+   4 root   sec_fac_cx500146_ds1       6 Sep 16 20:45 CX500146_DS1
```

## Storage: group scratch dirs I belong to

```
total 0
drwxrwx---. 2 root   sec_fac_cx500146_ds1   4096 Sep 16 20:45 CX500146_DS1
```

## Storage: my scratch

```
total 0
drwx------. 2 kanderson6 kanderson6 4096 Sep 16 20:45 .
drwxr-xr-x. 2 root       root       4096 Sep 16 20:34 ..
drwxr-xr-x. 2 kanderson6 kanderson6 4096 Sep 16 20:50 apptainer
```

## Modules: default loaded

```

Currently Loaded Modules:
  1) autotools   3) gnu14/14.2.0   5) ucx/1.18.0         7) openmpi5/5.0.7
  2) prun/2.2    4) hwloc/2.12.0   6) libfabric/1.18.0   8) ohpc

 

```

## Modules: top level

```

------------------------------ /etc/modulefiles -------------------------------
   CBI    RAD    Sali    nvidia-hpc

------------------- /opt/ohpc/pub/moduledeps/gnu14-openmpi5 -------------------
   boost/1.88.0     imb/2021.3    scalasca/2.6.2    tau/2.31.1
   dimemas/5.4.2    omb/7.5       scorep/9.0
   extrae/3.8.3     otf2/3.1.1    sionlib/1.7.7

----------------------- /opt/ohpc/pub/moduledeps/gnu14 ------------------------
   cubelib/4.9     likwid/5.4.1       opari2/2.0.9
   cubew/4.9       mpich/3.4.3-ofi    openmpi5/5.0.7   (L)
   gotcha/1.0.8    mvapich2/2.3.7     pdtoolkit/3.25.1

-------------------------- /opt/ohpc/pub/modulefiles --------------------------
   autotools    (L)    hwloc/2.12.0     (L)    os            prun/2.2   (L)
   cmake/4.1.2         libfabric/1.18.0 (L)    papi/6.0.0    ucx/1.18.0 (L)
   gnu14/14.2.0 (L)    ohpc             (L)    pmix/4.2.9

  Where:
   L:  Module is loaded

If the avail list is too long consider trying:

"module --default avail" or "ml -d av" to just list the default modules.
"module overview" or "ml ov" to display the number of modules for each name.

Use "module spider" to find all possible modules and extensions.
Use "module keyword key1 key2 ..." to search for all possible modules matching
any of the "keys".


```

## Modules: CBI collection

```

------------------------ /mnt/software/cbi/modulefiles ------------------------
   CBI-testing                   igv/2.19.7                 (D)
   action-validator/0.7.1        imagemagick/7.1.2-30
   action-validator/0.8.0        imagemagick/7.1.2-31       (D)
   action-validator/0.9.0 (D)    jq/1.8.2
   apache-ant/1.10.15            julia/1.12.4
   apache-ant/1.10.18     (D)    julia/1.12.5
   asciigenome/1.19.0            julia/1.12.6
   asciigenome/1.20.0     (D)    julia/1.13.0               (D)
   aws-cli/1.44.87               kallisto/0.51.1
   bamutil/1.0.14                kallisto/0.52.0            (D)
   bat/0.26.1                    libarmadillo/15.6.0
   bats-assert/2.2.4             llmfit/1.1.6
   bats-core/1.13.0              llmfit/1.1.14              (D)
   bats-core/1.14.0       (D)    markdown-link-check/3.14.2
   bats-file/0.4.0               markdownlint-cli/0.49.1
   bats-support/0.3.0            matlab/R2025b
   bcftools/1.22                 mc/4.8.33
   bcftools/1.23                 miniforge3-python2/2.7.15
   bcftools/1.23.1               miniforge3/25.11.0-1
   bcftools/1.24          (D)    miniforge3/26.1.0-0
   bedops/2.4.41                 miniforge3/26.3.2-2
   bedops/2.4.42          (D)    miniforge3/26.3.2-3        (D)
   bedtools2/2.31.1              mutect/1.1.5
   blast/2.17.0                  ncdu/2.9.1
   blat/39x1                     netcdf/4.10.1
   bowtie/1.3.1                  nextflow/26.04.6
   bowtie2/2.5.4                 node/22.22.0
   bowtie2/2.5.5          (D)    node/22.22.3
   bwa/0.7.19                    node/24.13.1
   byobu/5.133                   node/24.15.0
   cellranger/10.1.0             node/24.18.0               (D)
   chafa/1.18.1                  openjdk/17.0.0.1+2
   chafa/1.18.2           (D)    openjdk/21+35
   clp/1.17.7                    openjdk/25.0.2
   cmake/3.26.5                  openjdk/27                 (D)
   cmake/3.29.9                  pandoc/3.10.1
   cmake/3.31.11                 picard/3.4.0
   cmake/4.2.3                   pindel/0.2.5b8
   cmake/4.3.1                   plink/1.90b6.26
   cmake/4.3.2                   plink2/2.0.0-a.6.21
   cmake/4.3.3            (D)    port4me/0.7.1
   conda-stage/0.9.0             procs/0.14.12
   control-freec/11.6            proj/9.7.0
   cufflinks/2.2.1               proj/9.8.1                 (D)
   deno/2.7.14                   python/3.14.6
   deno/2.8.0                    quarto/1.9.38
   deno/2.8.1                    quarto/1.10.18             (D)
   deno/2.9.0                    rclone/1.74.4
   deno/2.9.4                    redis/7.4.8
   deno/2.9.5             (D)    restic/0.19.1
   difftastic/0.70.0             ripgrep/15.2.0
   dmtcp/4.1.1                   rust/1.93.0
   dmtcp/4.2.0            (D)    rust/1.94.0
   fastqc/0.12.1                 rust/1.95.0
   fclones/0.35.0                rust/1.96.0
   firefox/154.0                 rust/1.97.1
   fzf/0.74.3                    rust/1.98.1                (D)
   gatk/4.6.2.0                  salmon/1.10.0
   gatk/4.7.0.0           (D)    salmon/1.11.4              (D)
   gcta/1.94.0beta               samtools/1.22.1
   geos/3.14.1                   samtools/1.23
   ghostscript/10.05.0           samtools/1.23.1
   git-extras/7.5.0              samtools/1.24              (D)
   git-flow/1.12.3               shellcheck-repl/0.5.0
   github-cli/2.98.0             shellcheck/0.11.0
   gitleaks/8.30.0               snakemake/9.27.0
   gitleaks/8.30.1        (D)    snpeff/5.2c
   gitui/0.28.1                  snpeff/5.4c                (D)
   globus-cli/3.41.0             spacer/0.5.0
   glow/3.0.0                    sqlcmd/1.10.0
   glpk/5.0                      sratoolkit/3.2.0
   go/1.25.6                     sratoolkit/3.2.1
   go/1.26.0                     sratoolkit/3.4.1           (D)
   go/1.26.1                     star/2.7.11b
   go/1.26.3                     symphony/5.7.3
   go/1.26.4                     tinytex/2026.09
   go/1.26.5                     tophat/2.1.1
   go/1.27.0              (D)    trash-cli/0.24.5.26
   gping/1.20.1                  trimgalore/2.2.0
   gsl/2.8                       typst/0.15.1
   hdf5/1.14.6                   uv/0.11.24
   hisat2/2.2.1                  uv/0.11.32                 (D)
   htslib/1.22.1                 varscan/2.4.6
   htslib/1.23                   vcf-validator/0.10.2
   htslib/1.23.1                 vcftools/0.1.17
   htslib/1.24            (D)    x86-64-level/0.3.0
   htstools/0.1.1                yq/4.53.3
   igv/2.19.6

-------------------- /mnt/software/cbi/modulefiles/_rocky9 --------------------
   cutadapt/5.1        opencv/4.14.0    r/4.5.3            (D)
   emacs/30.2          r/4.4.3-gcc15    scl-gcc-toolset/15
   gdal/3.13.2         r/4.4.3          sqlite/3.51.2
   gdal/3.13.3  (D)    r/4.5.2-gcc15    sqlite/3.53.1
   htop/3.5.3          r/4.5.2          sqlite/3.53.4      (D)
   jags/4.3.2          r/4.5.3-gcc15

------------------------------ /etc/modulefiles -------------------------------
   CBI (L)    RAD    Sali    nvidia-hpc

------------------- /opt/ohpc/pub/moduledeps/gnu14-openmpi5 -------------------
   boost/1.88.0     imb/2021.3    scalasca/2.6.2    tau/2.31.1
   dimemas/5.4.2    omb/7.5       scorep/9.0
   extrae/3.8.3     otf2/3.1.1    sionlib/1.7.7

----------------------- /opt/ohpc/pub/moduledeps/gnu14 ------------------------
   cubelib/4.9     likwid/5.4.1       opari2/2.0.9
   cubew/4.9       mpich/3.4.3-ofi    openmpi5/5.0.7   (L)
   gotcha/1.0.8    mvapich2/2.3.7     pdtoolkit/3.25.1

-------------------------- /opt/ohpc/pub/modulefiles --------------------------
   autotools    (L)    hwloc/2.12.0     (L)    os            prun/2.2   (L)
   cmake/4.1.2         libfabric/1.18.0 (L)    papi/6.0.0    ucx/1.18.0 (L)
   gnu14/14.2.0 (L)    ohpc             (L)    pmix/4.2.9

  Where:
   D:  Default Module
   L:  Module is loaded

If the avail list is too long consider trying:

"module --default avail" or "ml -d av" to just list the default modules.
"module overview" or "ml ov" to display the number of modules for each name.

Use "module spider" to find all possible modules and extensions.
Use "module keyword key1 key2 ..." to search for all possible modules matching
any of the "keys".


```

## Modules: Sali collection

```

------------------------- /mnt/software/sali/modules --------------------------
   Cython/0.29.36                      python3/h5py/2.10.0
   Cython/3.0.5                 (D)    python3/h5py/3.14.0               (D)
   ImageMagick/6.8.8.10                python3/hdbscan/0.8.33
   allosmod                            python3/hdbscan/0.8.41            (D)
   anaconda/py311-2024.02              python3/ihm/1.8
   blast+/2.2.25                       python3/ihm/2.5
   blast+/2.2.28                       python3/ihm/2.7
   blast+/2.12.0                (D)    python3/ihm/2.9
   blast/2.2.26                        python3/ihm/2.11                  (D)
   boost/1.73.0                        python3/importlib-metadata/3.3.0
   cereal/1.3.2                        python3/importlib_resources/6.4.5
   cgal/4.12.1                         python3/iniconfig/1.1.1
   cgal/5.1                     (D)    python3/jax-cpu/0.9.0
   concavity/0.1                       python3/jax-cuda12/0.9.0
   conda-forge/py313-26.1.0            python3/joblib/0.17.0
   cryptosite                          python3/joblib/1.5.2              (D)
   cuda/6.0.37                         python3/kiwisolver/1.1.0
   cuda/7.5.18                         python3/kiwisolver/1.4.7          (D)
   cuda/8.0.61                         python3/matplotlib/3.1.2
   cuda/9.0.176                        python3/matplotlib/3.9.4          (D)
   cuda/10.0.130                       python3/mccabe/0.6.1
   cuda/11.5.0                         python3/mccabe/0.7.0              (D)
   cuda/12.4.0                         python3/mdp/3.6
   cuda/12.8.1                  (D)    python3/modelcif/1.2
   doxygen/1.8.6                       python3/modelcif/1.3              (D)
   doxygen/1.8.15               (D)    python3/msgpack/0.6.2
   dssp/2.0.4                          python3/networkx/2.4
   dssp/2.2.1                   (D)    python3/nose/1.3.7
   eigen/3.3.5                         python3/numexpr/2.8.1
   featuresketch/3.0                   python3/numexpr/2.10.2            (D)
   fpocket/2.0                         python3/numpy/1.19.5
   gcc/5.1.1                           python3/numpy/2.0.2               (D)
   gcc/6.4.1                           python3/packaging/20.8
   gcc/7.3.1                           python3/packaging/24.2            (D)
   gcc/10.2.1                   (D)    python3/pandas/0.25.3
   ghostscript/8.70                    python3/pandas/2.3.3              (D)
   gnuplot/5.0.5                       python3/pillow/11.3.0
   gnuplot/5.4.2                (D)    python3/pkgconfig/1.5.1
   hdf5/1.8.14                         python3/pluggy/0.13.1
   hdf5/1.8.17                         python3/protobuf/3.11.2
   hdf5/1.10.1                         python3/py/1.11.0
   hdf5/1.10.5                         python3/pycodestyle/2.6.0
   hdf5/1.10.6                         python3/pycodestyle/2.9.1         (D)
   hdf5/1.10.7                  (D)    python3/pyflakes/2.2.0
   imod/4.5.7                          python3/pyflakes/2.5.0            (D)
   imp-fast/last_ok_build              python3/pyparsing/2.4.5
   imp-fast/nightly                    python3/pyparsing/3.2.5           (D)
   imp-fast/2.24.0              (D)    python3/pyrmsd/4.3.2
   imp/last_ok_build                   python3/pyrmsd/4.3.3              (D)
   imp/nightly                         python3/pytest/6.2.1
   imp/2.24.0                          python3/pytz/2019.3
   imp/2.25.0                   (D)    python3/pytz/2025.2               (D)
   itcell                              python3/scikit/0.21.3
   libtau/1.0.1                        python3/scikit/1.6.1              (D)
   mist                                python3/scipy/1.3.2
   modeller/SVN                 (D)    python3/scipy/1.13.1              (D)
   modeller/10.5                       python3/six/1.16.0
   modeller/10.6                       python3/tables/3.6.1
   modeller/10.7                       python3/tables/3.9.2              (D)
   modeller/10.8                       python3/tensorflow/2.19.1
   muscle/3.8.31                       python3/threadpoolctl/3.5.0
   ninja/1.6.0                         python3/toml/0.10.2
   ninja/1.8.2                  (D)    python3/typing-extensions/3.7.4.3
   opencv/4.3.0                        python3/typing-extensions/4.5.0
   patch_dock/1.3                      python3/typing-extensions/4.16.0  (D)
   phenix/1.19.1.4122                  python3/zipp/3.4.0
   profit/3.1                          relion/1.4
   psipred/4.0                         relion/2.0.6
   python3/attrs/20.3.0                relion/3.0.git9a02562             (D)
   python3/attrs/21.2.0         (D)    rosetta/3.5
   python3/biopython/1.75              rosetta/3.10                      (D)
   python3/biopython/1.85       (D)    sali-libraries
   python3/bottleneck/1.3.1            scwrl/4.0
   python3/bottleneck/1.5.0     (D)    svm_light/6.0.2
   python3/cycler/0.10.0               swig/3.0.12
   python3/dataclasses/0.8             swig/4.0.2
   python3/dateutil/2.8.1              swig/4.4.1                        (D)
   python3/dateutil/2.9.0.post0 (D)    usearch/4.0.43
   python3/decorator/4.4.1             usearch/10.0.240                  (D)
   python3/flake8/5.0.4                web_service
   python3/fonttools/4.60.2            zdock/3.0.2
   python3/future/0.18.2

------------------------------ /etc/modulefiles -------------------------------
   CBI    RAD    Sali (L)    nvidia-hpc

-------------------------- /opt/ohpc/pub/modulefiles --------------------------
   autotools       hwloc/2.12.0        os            prun/2.2
   cmake/4.1.2     libfabric/1.18.0    papi/6.0.0    ucx/1.18.0
   gnu14/14.2.0    ohpc                pmix/4.2.9

  Where:
   D:  Default Module
   L:  Module is loaded

If the avail list is too long consider trying:

"module --default avail" or "ml -d av" to just list the default modules.
"module overview" or "ml ov" to display the number of modules for each name.

Use "module spider" to find all possible modules and extensions.
Use "module keyword key1 key2 ..." to search for all possible modules matching
any of the "keys".


```

## Modules: RAD collection

```

------------------------ /mnt/software/rad/modulefiles ------------------------
   SCS/ANTs/1.9
   SCS/ANTs/2.5.0                       (D)
   SCS/BART/v0.9.00
   SCS/DTK/latest
   SCS/ITK-SNAP/3.6.0
   SCS/ITK-SNAP/3.8.0
   SCS/ITK-SNAP/4.4.0                   (D)
   SCS/ImageJ/latest
   SCS/MINC-Toolkit-v2/Release-1.9.18.4
   SCS/MRIcro/1.39
   SCS/MRIcroGL/1.2.20220720
   SCS/MRIcron/1.0.20190902
   SCS/SIVIC
   SCS/TrackVis/latest
   SCS/afni/latest
   SCS/anaconda/anaconda3
   SCS/apptainer/apptainer
   SCS/apptainer/mount                  (D)
   SCS/base
   SCS/connectome/workbench
   SCS/dcmtk/3.6.7
   SCS/dcmtk/3.6.9
   SCS/dcmtk/3.7.0-tls
   SCS/dcmtk/3.7.0                      (D)
   SCS/freesurfer/infant-dev-4a14499
   SCS/freesurfer/7.4.1                 (D)
   SCS/fsl/fsl_latest
   SCS/fsl/5.0.8                        (D)
   SCS/gdcm/3.0.24
   SCS/matlab/R2025b
   SCS/mcr/v97
   SCS/mcr/v914                         (D)
   SCS/miniforge/miniforge3
   SCS/paraview/latest
   SCS/slicer/5.8.1
   SCS/slicer/5.10.0                    (D)
   SCS/tesseract/latest

------------------------------ /etc/modulefiles -------------------------------
   CBI    RAD (L)    Sali    nvidia-hpc

-------------------------- /opt/ohpc/pub/modulefiles --------------------------
   autotools       hwloc/2.12.0        os            prun/2.2
   cmake/4.1.2     libfabric/1.18.0    papi/6.0.0    ucx/1.18.0
   gnu14/14.2.0    ohpc                pmix/4.2.9

  Where:
   D:  Default Module
   L:  Module is loaded

If the avail list is too long consider trying:

"module --default avail" or "ml -d av" to just list the default modules.
"module overview" or "ml ov" to display the number of modules for each name.

Use "module spider" to find all possible modules and extensions.
Use "module keyword key1 key2 ..." to search for all possible modules matching
any of the "keys".


```

## Modules: nvidia-hpc collection

```

----------------------- /opt/nvidia/hpc_sdk/modulefiles -----------------------
   nvhpc-byo-compiler/25.1                nvhpc-hpcx-cuda13-openmpi5/26.5
   nvhpc-byo-compiler/26.5         (D)    nvhpc-hpcx-cuda13/26.5
   nvhpc-hpcx-2.20-cuda12/25.1            nvhpc-hpcx/25.1
   nvhpc-hpcx-2.20-cuda12/26.5     (D)    nvhpc-hpcx/26.5                 (D)
   nvhpc-hpcx-cuda12-openmpi4/26.5        nvhpc-nompi/25.1
   nvhpc-hpcx-cuda12-openmpi5/26.5        nvhpc-nompi/26.5                (D)
   nvhpc-hpcx-cuda12/25.1                 nvhpc/25.1
   nvhpc-hpcx-cuda12/26.5          (D)    nvhpc/26.5                      (D)
   nvhpc-hpcx-cuda13-openmpi4/26.5

------------------------------ /etc/modulefiles -------------------------------
   CBI    RAD    Sali    nvidia-hpc (L)

-------------------------- /opt/ohpc/pub/modulefiles --------------------------
   autotools       hwloc/2.12.0        os            prun/2.2
   cmake/4.1.2     libfabric/1.18.0    papi/6.0.0    ucx/1.18.0
   gnu14/14.2.0    ohpc                pmix/4.2.9

  Where:
   D:  Default Module
   L:  Module is loaded

If the avail list is too long consider trying:

"module --default avail" or "ml -d av" to just list the default modules.
"module overview" or "ml ov" to display the number of modules for each name.

Use "module spider" to find all possible modules and extensions.
Use "module keyword key1 key2 ..." to search for all possible modules matching
any of the "keys".


```

## Apptainer

```
/usr/bin/apptainer
apptainer version 1.5.2-1.el9
subuid entry: 0 (1 = --fakeroot allowed)
```

## Apptainer site config (bind paths)

```
allow user ns = yes
mount proc = yes
mount sys = yes
mount dev = yes
mount devpts = yes
mount home = yes
mount tmp = yes
mount hostfs = no
bind path = /etc/localtime
bind path = /etc/hosts
user bind control = yes
enable fusemount = yes
mount slave = yes
use nvidia-container-cli = no
```

## Internet proxy on login node

```
no_proxy=127.0.0.1,localhost
https_proxy=http://chpc-proxy-vm1:3128
NO_PROXY=127.0.0.1,localhost
HTTPS_PROXY=http://chpc-proxy-vm1:3128
HTTP_PROXY=http://chpc-proxy-vm1:3128
http_proxy=http://chpc-proxy-vm1:3128
HTTP/1.1 200 Connection established
```

## Python / conda

```
conda ()
{ 
    \local cmd="${1-__missing__}";
    case "$cmd" in 
        activate | deactivate)
            __conda_activate "$@"
        ;;
        install | update | upgrade | remove | uninstall)
            __conda_exe "$@" || \return;
            __conda_activate reactivate
        ;;
        *)
            __conda_exe "$@"
        ;;
    esac
}
/mnt/software/cbi/software/miniforge3-26.3.2-3/condabin/mamba
/mnt/software/cbi/software/miniforge3-26.3.2-3/bin/python
conda 26.5.3
_CONDA_ROOT=/mnt/software/cbi/software/miniforge3-26.3.2-3
```

## Misc tools

```
tmux         /usr/bin/tmux
screen       /usr/bin/screen
git          /usr/bin/git
rsync        /usr/bin/rsync
globus       -
nvidia-smi   -
jupyter      -
singularity  /usr/bin/singularity
```

## Current queue (all users, summary)

```
      2 community RUNNING
   1001 cpu PENDING
    250 cpu RUNNING
      1 gpu COMPLETING
     85 gpu PENDING
     31 gpu RUNNING
     62 large_gpu PENDING
     83 large_gpu RUNNING
     17 pod PENDING
     11 pod RUNNING
```

## My recent jobs (7 days)

```
JobID|JobName|Partition|State|Elapsed|MaxRSS|AllocTRES
```
