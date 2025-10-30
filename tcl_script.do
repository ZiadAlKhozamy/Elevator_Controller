test1:

vsim work.elevatorcontroller
add wave *
force -freeze sim:/elevatorcontroller/clk 0 0, 1 {2 ps} -r 5
run 500 ps
force -freeze sim:/elevatorcontroller/rst 0 0
run 50 ps
force -freeze sim:/elevatorcontroller/rst 1 0
run 50 ps
force -freeze sim:/elevatorcontroller/switches 1000 0
run 500 ps
force -freeze sim:/elevatorcontroller/accept 0 0
run 10000 ps

---------------------------------------------------------------------------------------------------------------
test2 : 
restart -force
wave clear
vsim work.elevatorcontroller
add wave *
force -freeze sim:/elevatorcontroller/clk 0 0, 1 {2 ps} -r 5
run 500 ps
force -freeze sim:/elevatorcontroller/rst 1 0
run 50 ps
force -freeze sim:/elevatorcontroller/rst 0 0
run 50 ps
force -freeze sim:/elevatorcontroller/rst 1 0
run 50 ps
force -freeze sim:/elevatorcontroller/switches 1000 0
run 500 ps
force -freeze sim:/elevatorcontroller/accept 1 0
run 100 ps
force -freeze sim:/elevatorcontroller/accept 0 0
run 100 ps
force -freeze sim:/elevatorcontroller/accept 1 0
force -freeze sim:/elevatorcontroller/switches 0101 0
run 50 ps
force -freeze sim:/elevatorcontroller/accept 0 0
run 50 ps
force -freeze sim:/elevatorcontroller/accept 1 0
run 50 ps
force -freeze sim:/elevatorcontroller/switches 0000 0 
force -freeze sim:/elevatorcontroller/accept  0
run 50 ps
force -freeze sim:/elevatorcontroller/accept 1 0
run 50 ps
force -freeze sim:/elevatorcontroller/switches 1001 0 
force -freeze sim:/elevatorcontroller/accept 0 0
run 50 ps
force -freeze sim:/elevatorcontroller/accept 1 0
run 50 ps
run 10000 ps

---------------------------------------------------------------------------------------------------------------
test3 : 
restart -force
wave clear
vsim work.elevatorcontroller
add wave *
force -freeze sim:/elevatorcontroller/clk 0 0, 1 {2 ps} -r 5
run 500 ps
force -freeze sim:/elevatorcontroller/rst 0 0
run 50 ps
force -freeze sim:/elevatorcontroller/rst 1 0
run 50 ps
force -freeze sim:/elevatorcontroller/accept 1 0
run 100 ps
force -freeze sim:/elevatorcontroller/switches 1000 0
run 500 ps
force -freeze sim:/elevatorcontroller/accept 0 0
run 100 ps
force -freeze sim:/elevatorcontroller/accept 1 0
run 100 ps
force -freeze sim:/elevatorcontroller/accept 0 0
force -freeze sim:/elevatorcontroller/switches 0101 0
run 50 ps
force -freeze sim:/elevatorcontroller/accept 1 0
run 50 ps
force -freeze sim:/elevatorcontroller/switches 0000 0 
force -freeze sim:/elevatorcontroller/accept 0 0
run 50 ps
force -freeze sim:/elevatorcontroller/accept 1 0
run 50 ps
force -freeze sim:/elevatorcontroller/switches 1001 0 
force -freeze sim:/elevatorcontroller/accept 0 0
run 50 ps
force -freeze sim:/elevatorcontroller/accept 1 0
run 50 ps
force -freeze sim:/elevatorcontroller/switches 1001 0 
force -freeze sim:/elevatorcontroller/accept 0 0
run 50 ps
force -freeze sim:/elevatorcontroller/accept 1 0
run 2000 ps
force -freeze sim:/elevatorcontroller/switches 0001 0 
force -freeze sim:/elevatorcontroller/accept 0 0
run 50 ps
force -freeze sim:/elevatorcontroller/accept 1 0
run 10000 ps 

---------------------------------------------------------------------------------------------------------------
final test:
restart -force
wave clear

force -freeze sim:/counter2sec/clk 0 0, 1 {10000 ps} -r 20000
force -freeze sim:/counter2sec/enable 0 0
run 100 ns
force -freeze sim:/counter2sec/enable 1 0
run 500 ns
run 4000 ms
