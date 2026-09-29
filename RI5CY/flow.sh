#!/usr/bin/bash

## Available modes: 
# * --v --> Typical Verilog testbench (Available)
# * --sv --> Typical SystemVerilog testbench (Soon)
# * --uvm --> Typical UVM environment (Soon)

## Reorder the files in the list for the correct compilation order
# 1- packages
# 2- Interfaces
# 3- Assertions
# 4- Monitor module
# 5- Design files (Last one is the DUT)
# 6- Testbench 
# 7- Top-level Testbench
## Create the function for each mode 

sort_by_hierarchy (){
    local arr_name=$1
    local -n input_arr=$arr_name
    local -n output=$3
    arr_length=${#input_arr[@]}
    target_file=$2
    output_arr=()
    temp_arr=(${input_arr[@]}) # Contains the remaining files for searching
    i=0
    prev_output_len=-1
    while [ ${#output_arr[@]} -ne $arr_length ]; do
        for file in "${temp_arr[@]}" ; do
            module_name=$(grep -oP '^\s*module\s+\K[A-Za-z_][A-Za-z0-9_]*' "$file" | head -1)
            if [ -n "$module_name" ] && grep -qw "$module_name" "$target_file"; then
                output_arr+=("$file")
            fi
            
        done
        # exit

        temp_arr=()
        # Remove the checked files from the temp_array
        for input_file in "${input_arr[@]}" ; do
            exist='n'
            for output_file in "${output_arr[@]}" ; do
                if [ "$input_file" = "$output_file" ]; then
                    exist='y'
                fi
            done
            if [ "$exist" = 'n' ]; then
                temp_arr+=("$input_file")
            fi
        done

        # Safety guard: if a full pass made no progress, append the
        # remaining files as-is and stop, instead of looping forever.
        if [ ${#output_arr[@]} -eq $prev_output_len ]; then
            for file in "${temp_arr[@]}" ; do
                output_arr+=("$file")
            done
            break
        fi
        prev_output_len=${#output_arr[@]}

        target_file=${output_arr[i]}
        (( i++ ))
    done
    final_output_arr=()
    for (( i=${#output_arr[@]} - 1; i >= 0; i-- )); do
        final_output_arr+=("${output_arr[i]}")
    done
    
    output=(${final_output_arr[@]})

}

function Compilation_reorder(){ 
# Input : list file
# Output : DUT file name , DUT module name , Testbench file name , Testbench module name --> gathered into <output> array passed by reference in the second argument

    local -n output=$2

    ## Package pattern
    pkg_pattern=".*p.?.?k.?g.?.*.sv"
    interface_pattern=".*_i.?.?.?.?f.?.?.?_*.sv"
    sva_pattern1=".*assert.?.?.?.?.*.sv"
    sva_pattern2=".*sva.*.sv"
    sva_pattern3=".*ch.?.?k.*.sv"
    sva_patterns="$sva_pattern1|$sva_pattern2|$sva_pattern3"
    monitor_pattern=".*monitor_*.[v sv]" # Monitor module maybe used in verilog
    golden_ref_pattern1=".*gold.?.?.*.[v sv]"
    golden_ref_pattern2=".*ref.*.[v sv]"
    golden_ref_pattern3="g_.*.[v sv]"
    golden_ref_pattern4=".*_g.[v sv]"
    golden_ref_patterns="$golden_ref_pattern1|$golden_ref_pattern2|$golden_ref_pattern3|$golden_ref_pattern4"
    testbench_pattern=".*_t.?.?.?b.?.?.?.?.[v sv]"
    top_pattern=".*_top.sv"
    > temp_file
    ## 1- place the package file in the list file
    package_files=`grep -iE "$pkg_pattern" "$1"`
    [[ -n "$package_files" ]] && echo "$package_files" > temp_file # If the value of "Package_files" is not null , add it to the src_files 
    ## 2- place the interface file in the list file
    interface_files=`grep -iE "$interface_pattern" "$1"`
    [[ -n "$interface_files" ]] && echo "$interface_files" >> temp_file
    ## 3- place the sva file in the list file
    assertion_files=`grep -iE "$sva_patterns" "$1"` 
    [[ -n "$assertion_files" ]] && echo "$assertion_files" >> temp_file
    ## 4- place the monitor files in the list file
    monitor_files=`grep -iE "$monitor_pattern" "$1"`
    [[ -n "$monitor_files" ]] && echo "$monitor_files" >> temp_file
    ## 5- Search for the Golden_Ref Module but not place it now
    mapfile -t golden_ref_files < <(grep -iE "$golden_ref_patterns" "$1")
    ## 6- Search for the testbench file but not place it now
    testbench_file=`grep -iE "$testbench_pattern" "$1"` # Get the testbench for searching for the DUT
    ## 7- Search for the top file but not place it now
    top_file=`grep -iE "$top_pattern" "$1"` # Get the top for searching for the DUT if exists
    ## 8- Extract the design files that are not meeting the above criteria
    mapfile -t Design_files < <(grep -iEv "$pkg_pattern|$interface_pattern|$sva_patterns|$monitor_pattern|$testbench_pattern|$top_pattern|$golden_ref_patterns" "$1")
    # echo -e "The design files are : ${Design_files[@]}"

    # echo -e "Package files  : $package_file \n"
    # echo -e "Interface files : $interface_file \n"
    # echo -e "Assertion files : $assertion_file \n" 
    # echo -e "Monitor files : $monitor_files \n"
    # echo -e "Golden Ref files : $golden_ref_files \n" 
    # echo -e "Design files : $Design_files\n"
    # echo -e "Top file : $top_file\n"
    # echo -e "Testbench file : $testbench_file\n"
    # echo -e "testing ended\n"
    # exit
   
    
    if [ -z "$top_file" ];then
        top_flag=false
    else
        top_flag=true
    fi


    ## Place the design files sorted by hiererachy
    if [ "${#Design_files[@]}" -ne 0 ]; then # In case of not testing the Golden Reference Alone
        # echo "${Design_files[@]}"
        # echo "${#Design_files[@]}"
        declare -a Sorted_Design_files
        if [ -n "$testbench_file" ]; then
            if [ "$top_flag" = false  ]; then 
                sort_by_hierarchy Design_files "$testbench_file" Sorted_Design_files
            else
                sort_by_hierarchy Design_files "$top_file" Sorted_Design_files
            fi
           
            for file in ${Sorted_Design_files[@]}; do 
                echo $file >> temp_file
                # echo "I am here"
            done
        
        else
            Sorted_Design_files=($Design_files)
            testbench_file=($Design_files)
        fi
    fi

    # Place the Golden Reference files sorted by hiererachy
    if [ "${#golden_ref_files[@]}" -ne 0 ]; then
        declare -a Sorted_Golden_files
        if [ "$top_flag" = false  ]; then 
            sort_by_hierarchy golden_ref_files "$testbench_file" Sorted_Golden_files
        else
            sort_by_hierarchy golden_ref_files "$top_file" Sorted_Golden_files
        fi

        for file in ${Sorted_Golden_files[@]}; do 
            echo $file >> temp_file
        done
    
    fi


    if [ "${#Design_files[@]}" -ne 0  ]; then 
        DUT_file="${Sorted_Design_files[(( ${#Sorted_Design_files[@]} - 1 ))]}"
    else
        DUT_file="${Sorted_Golden_files[(( ${#Sorted_Golden_files[@]} - 1 ))]}"
    fi

    [[ -n "$testbench_file" ]] && echo "$testbench_file" >> temp_file
    # echo "$top_file"
    [[ -n "$top_file" ]] && echo "$top_file" >> temp_file
    # exit
    mv temp_file "$1"

    # echo -e "Number of sorted design files : ${#Sorted_Design_files[@]}\n"
    # echo -e "Number of sorted golden files : ${#Sorted_Golden_files[@]}\n"
    # echo -e "Final Top file : $top_file\n"
    # echo -e "Final Testbench file : $testbench_file\n"
    # echo -e "DUT file : $DUT_file\n"

    output=("$1" "$DUT_file" "$top_flag" "$testbench_file" "$top_file")
    # exit
}


function crt_do() { # compilation info , --option, cover, quiet ## creating the do file 

    local -n info=$1 # list filename , DUT filename , top flag , testbench filename , top filename
    option="$2"
    cover_flag="$3"
    quiet_flag="$4"
    
    ##----------------------------------------------------------------------------------
    list_filename="${info[0]}"
    DUT_base="${info[1]##*/}"      # strip directory path
    DUT_filename="${DUT_base%.*}"  # strip extension
    tb_filename="${info[3]}"
    top_exists_flag="${info[2]}"
    if [ "$top_exists_flag" = "true" ];then
        top_filename="${info[4]}"
    fi
    
    keep_do=""
    
    do_filename="${DUT_filename}_do.do"
    
    if [ -e "$do_filename" ]; then
        read -p "Do you want to keep the existing .do file? (Enter/n) : " do_check
        if [ "$do_check" = "" ]; then
            keep_do="y"
        else 
            keep_do="n"
        fi
    else
        keep_do="n"
    fi

    ## If keeping the existing .do file, detect its current quiet setting
    ## (presence of "add wave *" means it was generated non-quiet) and patch
    ## the relevant lines in place if the requested quiet_flag now differs,
    ## instead of forcing a full regeneration.
    if [ "$keep_do" = "y" ]; then
        if grep -q "^add wave \*$" "$do_filename"; then
            existing_quiet=false
        else
            existing_quiet=true
        fi

        if [ "$quiet_flag" != "$existing_quiet" ]; then
            echo "Quiet setting changed since the last run — updating the existing .do file in place..."
            if [ "$quiet_flag" = true ]; then
                # Switching non-quiet -> quiet
                sed -i 's/\]} { return }$/]} { quit }/' "$do_filename"
                sed -i 's/quit -sim } $/quit } /' "$do_filename"
                sed -i '/^add wave \*$/d' "$do_filename"
            else
                # Switching quiet -> non-quiet
                sed -i 's/\]} { quit }$/]} { return }/' "$do_filename"
                sed -i 's/quit } $/quit -sim } /' "$do_filename"
                if ! grep -q "^add wave \*$" "$do_filename"; then
                    sed -i '/^run -all$/i add wave *' "$do_filename"
                fi
            fi
        fi
    fi

    if [ "$keep_do" = "n" ]; then
        touch "$do_filename"
        echo "quit -sim" > "$do_filename"
        echo "vlib work" >> "$do_filename"

        ## Compilation
        echo "if {[catch {vlog -f $list_filename " >> "$do_filename"

        if [ "$cover_flag" == true ]; then 
            case $2 in 
                --v)
                    echo -e "Can't use cover options in Verilog testbench \nDon't use -c with --v"
                    echo -e "Ignoring -c option .......\n"
                    exit
                    ;;
                --sv|--uvm)
                    sed -i '$ s/$/ +cover -covercells } /' "$do_filename"
                    ;;
            esac
        else 
             sed -i '$ s/$/ } /' "$do_filename"
        fi

        if [ "$quiet_flag" = false ]; then
            sed -i '$ s/$/ -l compile.log]} { return }/' "$do_filename" 
        else
            sed -i '$ s/$/ ]} { quit }/' "$do_filename" 
        fi
        

        ## Simulation
        # pattern1="_[tT].*[bB]" # to match file named as "***_tb" 
        # pattern2="_[tT][oO][pP]" # to match file named as "_top" for the SV interface
        echo "if {[catch {vsim -voptargs=+acc work." >> "$do_filename"
       

        tb_module_name=$(grep -oP '^\s*module\s+\K[A-Za-z_][A-Za-z0-9_]*' "$tb_filename" | head -1)


        if [ "$top_exists_flag" = false ];then
            sed -i "$ s/$/$tb_module_name/" "$do_filename"
        else
            top_module_name=$(grep -oP '^\s*module\s+\K[A-Za-z_][A-Za-z0-9_]*' "$top_filename" | head -1)
            sed -i "$ s/$/$top_module_name/" "$do_filename"
        fi

        if [ "$2" == "--uvm" ]; then 
                sed -i "$ s/$/ -uvmcontrol=all +UVM_NO_RELNOTES/" "$do_filename" 
        fi

        if [ "$cover_flag" == true ] && [ "$option" != "--v" ]; then
            sed -i "$ s/$/ -cover -classdebug/" "$do_filename"
        fi
        
        
        if [ "$quiet_flag" = false ]; then
            sed -i "$ s/$/  -sv_seed random -l sim.log } ]} { quit -sim } /"  "$do_filename" 
        else    
            sed -i "$ s/$/  -sv_seed random -l sim.log } ]} { quit } /"  "$do_filename" 
            
        fi
        
        if [ "$quiet_flag" = false ]; then
            echo "add wave *" >> "$do_filename" # should be edited in UVM environment 
        fi

        if [ "$cover_flag" == true ] && [ "$option" != "--v" ];
        then
            DUT_module_name=$(grep -oP '^\s*module\s+\K[A-Za-z_][A-Za-z0-9_]*' "${info[1]}" | head -1)
            echo "coverage save ${tb_module_name}.ucdb -onexit -du ${DUT_module_name} " >> "$do_filename"
        fi

        if [ "$option" == "--uvm" ]; then 
            echo -e "run 0" >> "$do_filename"
        fi

        echo -e "run -all" >> "$do_filename"

        if [ "$cover_flag" == true ] && [ "$option" != "--v" ];
        then
            echo "coverage report -detail -cvg -directive -comments -output ${DUT_filename}_Func_Covr.rpt" >> "$do_filename"
            echo "quit -sim " >> "$do_filename"
            echo "vcover report ${tb_module_name}.ucdb -annotate -all -details -output ${DUT_filename}_Code_Covr.rpt" >> "$do_filename"
        fi
    fi

    ## Open the simulator
    while :; do
        read -p "Do you want to start the simulation [Enter/n] : " prompt
        case $prompt in 
            "")
                if [ "$quiet_flag" == true ]; then
                    sed -i "/^quit$/d" "$do_filename"
                    echo "quit" >> "$do_filename"
                    vsim.exe -c -do "$do_filename"
                else
                    sed -i "/^quit$/d" "$do_filename"
                    vsim.exe -do "$do_filename"
                fi
                break
                ;;
            n|N) 
                code "$do_filename"
                if [ "$quiet_flag" == true ]; then
                    sed -i "/^quit$/d" "$do_filename"
                    echo "quit" >> "$do_filename"
                    echo "To start the simulation, run the following: vsim.exe -c -do $do_filename"
                else
                    sed -i "/^quit$/d" "$do_filename"
                    echo "To start the simulation, run the following: vsim.exe -do $do_filename"
                fi
                break
                ;;
            *)
                echo "Wrong Input .. please try again"
                continue
                ;;
        esac
    done
}

function crt_synth(){
    if [ "$vivado_path_windows" == "" ]
    then 
        found_flag=false
        while : ; do
        read -p " Enter the path to the Vivado batch file (vivado.bat) [in Windows format]: " vivado_path_windows
        if [ "$vivado_path_windows" == "" ]
        then   
            echo -e "Write the path correctly \n"
            continue
            else
                break 
        fi
        done
        echo  "## Vivado Config" >> ~/.bashrc
        echo  "export vivado_path_windows" >> ~/.bashrc
    else
        found_flag=true
    fi

    ## Make a shorthand for vivado (batch/tcl) mode
    vivado_existence=$(grep -i -c "vivado ()" ~/.bashrc)
    if [ "$vivado_existence" -eq 0 ]; then
        echo -e "function vivado () { " >> ~/.bashrc
        echo "cmd.exe /c \"\$vivado_path_windows\" \"-mode\" \"\$1\" \"-source\" \"\$2\"" >> ~/.bashrc
        echo "}" >> ~/.bashrc
    fi

    ## Create the TCL script of the Synthesis flow   

}
# ----------------- Main program -------------------------------------
USAGE="Usage: ./flow.sh [--v|--sv|--uvm] [-q/-c/-s] <Synthesis TCL file> <file_list.f> \n -q : Prints the output transcript\n -c : Print the coverage report(s)\n -s : Output the synthesis files (till bitstream)"
ARGS=("$@") 
NARGS=$#
quiet_flag=false
cvr_flag=false
synth_flag=false

## tests
# echo "${ARGS[(( $NARGS - 1 ))]}"

## Check that the command is inserted successfully
last_arg="${ARGS[(( NARGS - 1 ))]}"
ext="${last_arg##*.}"
if [ "$NARGS" -lt 2 ] || { [ "$ext" != "f" ] && [ "$ext" != "F" ]; } || { [ "${ARGS[0]}" != "--v" ] && [ "${ARGS[0]}" != "--sv" ] && [ "${ARGS[0]}" != "--uvm" ]; }
then
    echo -e "\nCommand is invalid, $USAGE\n"
    exit 0
fi

##  (--v/--sv/--uvm) (-q|-s|-c) <list file>
for (( i=1; i<$NARGS-1; i++ ))
do # 1st & last argument are known but the other options are not mandatory & need to be checked 
    case ${ARGS[$i]} in 
        -q)
            quiet_flag=true
            ;;
        -s) 
            synth_flag=true
            ;;
        -c)
            cvr_flag=true
            ;;
        *)
            echo -e "$USAGE \n"
            exit 0
            ;;
    esac       
done


declare -a compilation_info

Compilation_reorder "${ARGS[(( $NARGS - 1 ))]}" compilation_info

crt_do  compilation_info "$1" "$cvr_flag" "$quiet_flag" "$USAGE"

## Notes & Hints for the user @ the end of execution
synth_operation_status=$?
if [ "$synth_operation_status" -eq 0 ] && [ "$synth_flag" == "true" ]
then 
    echo -e "Please save the path to vivado using this command \n source ~/.bashrc"
fi


# Project status: 
# --v : Successful 
# --sv : Need to parse the DUT file considering a .(sv) DUT in SV interface 
# --UVM : Need to parse for all the UVM objects to add the wave correctly 
# Possible updates: 
# * Add the (-w) option --> To export the wave as .jpeg
#   ## Open the waveform window and display the signals
#   view wave
#   ## Run the simulation to the desired point
#   run -all
#   ## Export the waveform
#   waveform export -format jpeg -file my_waveform.jpg
# add watch -r /*