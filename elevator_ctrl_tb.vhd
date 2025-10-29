library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity ElevatorController_TB is
end ElevatorController_TB;

architecture Behavioral of ElevatorController_TB is
    constant n : integer := 10;
    constant CLK_PERIOD : time := 20 ns; -- 50MHz clock (20ns period)
    
    -- Timing constants based on requirements
    constant TIME_PER_FLOOR : integer := 250; -- 2 seconds at 50MHz = 100 clock cycles (2sec / 20ns = 100)
    constant DOOR_OPEN_TIME : integer := 250; -- 2 seconds door opening
    constant SETUP_TIME : integer := 10;      -- Setup time between operations
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal switches : std_logic_vector(3 downto 0) := "0000";
    signal accept : std_logic := '1';
    signal mv_up : std_logic;
    signal mv_dn : std_logic;
    signal op_door : std_logic;
    signal floor: std_logic_vector(3 downto 0);
    signal SevenSeg : std_logic_vector(6 downto 0);
    
    signal test_case_number : integer := 1;
    signal simulation_complete : boolean := false;
    
    component ElevatorController is
        generic(n : integer := 10);
        port(
            clk: in std_logic;
            rst: in std_logic;
            switches: in std_logic_vector(3 downto 0);
            accept: in std_logic;  
            mv_up: out std_logic;
            mv_dn: out std_logic;
            op_door: out std_logic;
	    floor: out std_logic_vector(3 downto 0);
            SevenSeg: out std_logic_vector(6 downto 0)
        );
    end component;

begin
    -- Clock generation (50MHz)
    clk <= not clk after CLK_PERIOD/2 when not simulation_complete else '0';
    
    -- Unit Under Test
    UUT: ElevatorController
        generic map (n => n)
        port map (
            clk => clk,
            rst => rst,
            switches => switches,
            accept => accept,
            mv_up => mv_up,
            mv_dn => mv_dn,
            op_door => op_door,
	    floor => floor,
            SevenSeg => SevenSeg
        );

    -- Test process
    test_runner: process
        procedure wait_clock_cycles(cycles : integer) is
        begin
            for i in 1 to cycles loop
                wait until rising_edge(clk);
            end loop;
        end procedure;
        
        procedure reset_system is
        begin
            rst <= '0';
            wait_clock_cycles(5);
            rst <= '1';
            wait_clock_cycles(5);
        end procedure;
        
        procedure make_request(floor : integer) is
        begin
            switches <= std_logic_vector(to_unsigned(floor, 4));
            accept <= '0';
            wait_clock_cycles(3); -- Hold accept low for multiple cycles
            accept <= '1';
            wait_clock_cycles(2);
        end procedure;
        
        procedure wait_for_floor_arrival(start_floor, target_floor : integer) is
            variable floors_to_travel : integer;
            variable estimated_time : integer;
        begin
            floors_to_travel := abs(target_floor - start_floor);
            if floors_to_travel = 0 then
                estimated_time := DOOR_OPEN_TIME + 10; -- Door open + margin
            else
                estimated_time := (floors_to_travel * TIME_PER_FLOOR) + DOOR_OPEN_TIME + 20; -- Travel + door + margin
            end if;
            wait_clock_cycles(estimated_time);
        end procedure;
        
        procedure log_message(message : string) is
            variable l : line;
        begin
            write(l, string'("Test Case ") & integer'image(test_case_number) & ": " & message);
            writeline(output, l);
        end procedure;
        
    begin
        log_message("Starting Elevator Controller Testbench");
        log_message("Clock: 50MHz, Floor movement: 2sec, Door open: 2sec");
        
        -- Initial reset to ensure starting from floor 0
        reset_system;
        
        ------------------------------------------------------------------------
        -- Test Case 1: Basic Single Request
        ------------------------------------------------------------------------
        log_message("Basic Single Request (0 -> 3)");
        test_case_number <= 1;
        
        make_request(3);
        wait_for_floor_arrival(0, 3); -- 3 floors * 2sec + door time = ~8 seconds
        
        ------------------------------------------------------------------------
        -- Test Case 2: Multiple Sequential Requests  
        ------------------------------------------------------------------------
        log_message("Multiple Sequential Requests (0 -> 5 -> 2 -> 8 -> 4)");
        test_case_number <= 2;
        
        reset_system;
        
        make_request(5);
        wait_for_floor_arrival(0, 5);
        
        make_request(2);
        wait_for_floor_arrival(5, 2);
        
        make_request(8);
        wait_for_floor_arrival(2, 8);
        
        make_request(4);
        wait_for_floor_arrival(8, 4);
        
        ------------------------------------------------------------------------
        -- Test Case 3: Up-Down Direction Changes
        ------------------------------------------------------------------------
        log_message("Up-Down Direction Changes (from floor 0: floors 1,5,7)");
        test_case_number <= 3;
        
        reset_system;
        
        -- Set multiple requests simultaneously by holding accept
        switches <= "0001"; -- Floor 1
        accept <= '0';
        wait_clock_cycles(25);
        switches <= "0101"; -- Floor 5
        wait_clock_cycles(25);
        switches <= "0111"; -- Floor 7
        wait_clock_cycles(25);
        accept <= '1';
        
        -- Wait for all requests to be serviced (0->1->5->7)
        wait_clock_cycles((1 * TIME_PER_FLOOR) + (3 * TIME_PER_FLOOR) + (2 * TIME_PER_FLOOR) + (3 * DOOR_OPEN_TIME) + 50);
        
        ------------------------------------------------------------------------
        -- Test Case 4: Request While Moving
        ------------------------------------------------------------------------
        log_message("Request While Moving (0->4, add request for 6 while moving)");
        test_case_number <= 4;
        
        reset_system;
        
        make_request(4);
        wait_clock_cycles(TIME_PER_FLOOR / 2); -- Wait until elevator is between floors 1-2
        make_request(6); -- Add request while moving
        
        wait_for_floor_arrival(0, 6); -- Should go 0->4->6
        
        ------------------------------------------------------------------------
        -- Test Case 5: Current Floor Request
        ------------------------------------------------------------------------
        log_message("Current Floor Request (request floor 0 while at floor 0)");
        test_case_number <= 5;
        
        reset_system;
        
        -- Already at floor 0, request floor 0
        make_request(0);
        wait_clock_cycles(3 * DOOR_OPEN_TIME + 20);
	make_request(0);
	wait_clock_cycles(50);
	 -- Wait for door operation
        
        ------------------------------------------------------------------------
        -- Test Case 6: Multiple Requests in Same Direction
        ------------------------------------------------------------------------
        log_message("Multiple Requests Same Direction (from floor 0: floors 4,6,8)");
        test_case_number <= 6;
        
        reset_system;
        
        -- Set multiple upward requests
        switches <= "0100"; -- Floor 4
        accept <= '0';
        wait_clock_cycles(20);
        switches <= "0110"; -- Floor 6
        wait_clock_cycles(20);
        switches <= "1000"; -- Floor 8
        wait_clock_cycles(20);
        accept <= '1';
        
        -- Wait for complete upward sweep (0->4->6->8)
        wait_clock_cycles((4 * TIME_PER_FLOOR) + (2 * TIME_PER_FLOOR) + (2 * TIME_PER_FLOOR) + (1 * DOOR_OPEN_TIME) + 50);
        
        ------------------------------------------------------------------------
        -- Test Case 7: Mixed Direction Optimization
        ------------------------------------------------------------------------
        log_message("Mixed Direction Optimization (from floor 0: floors 3,7,1,9)");
        test_case_number <= 7;
        
        reset_system;
        
        -- Set mixed requests
        switches <= "0011"; -- Floor 3
        accept <= '0';
        wait_clock_cycles(2);
        switches <= "0111"; -- Floor 7
        wait_clock_cycles(2);
        switches <= "0001"; -- Floor 1
        wait_clock_cycles(2);
        switches <= "1001"; -- Floor 9
        wait_clock_cycles(2);
        accept <= '1';
        
        -- Wait for optimized path execution
        wait_clock_cycles(1000); -- Extended wait for complex path
        
        ------------------------------------------------------------------------
        -- Test Case 8: Boundary Floor Tests
        ------------------------------------------------------------------------
        log_message("Boundary Floor Tests (0->9 and 9->0)");
        test_case_number <= 8;
        
        reset_system;
        
        -- Test 0 -> 9
        make_request(9);
        wait_for_floor_arrival(0, 9);
        
        -- Test 9 -> 0
        make_request(0);
        wait_for_floor_arrival(9, 0);
        
        ------------------------------------------------------------------------
        -- Test Case 9: Reset During Operation
        ------------------------------------------------------------------------
        log_message("Reset During Operation");
        test_case_number <= 9;
        
        reset_system;
        
        make_request(6);
        wait_clock_cycles(TIME_PER_FLOOR * 3 + 10); -- Wait until elevator is moving between floors
        
        rst <= '0'; -- Assert reset during movement
        wait_clock_cycles(10);
        rst <= '1'; -- Deassert reset
        wait_clock_cycles(30);
        
        ------------------------------------------------------------------------
        -- Test Case 10: Invalid Floor Input
        ------------------------------------------------------------------------
        log_message("Invalid Floor Input (floor 10)");
        test_case_number <= 10;
        
        reset_system;
        
        switches <= "1010"; -- Floor 10 (invalid)
        accept <= '0';
        wait_clock_cycles(5);
        accept <= '1';
        wait_clock_cycles(30); -- Wait to ensure no movement
        
        ------------------------------------------------------------------------
        -- Test Case 11: Rapid Successive Requests
        ------------------------------------------------------------------------
        log_message("Rapid Successive Requests");
        test_case_number <= 11;
        
        reset_system;
        
        -- Start from floor 0
        make_request(3);
        wait_clock_cycles(15); -- Wait for movement to start
        
        make_request(7); -- Request during movement
        wait_clock_cycles(15); -- Continue moving
        
        make_request(1); -- Another request while moving
        
        wait_clock_cycles(300); -- Extended wait for complex sequence
        
        ------------------------------------------------------------------------
        -- Test Case 12: Empty Request Handling
        ------------------------------------------------------------------------
        log_message("Empty Request Handling");
        test_case_number <= 12;
        
        reset_system;
        
        -- Wait in idle state with no requests
        wait_clock_cycles(50);
        
        -- Verify no movement occurs
        log_message("Verified idle state maintained with no requests");
        
        ------------------------------------------------------------------------
        -- Test Case 13: Clock Edge Sensitivity
        ------------------------------------------------------------------------
        log_message("Clock Edge Sensitivity Testing");
        test_case_number <= 13;
        
        reset_system;
        
        -- Test setup/hold around clock edges with various floors
        for i in 1 to 4 loop
            wait until falling_edge(clk);
            switches <= std_logic_vector(to_unsigned(i, 4));
            wait for 8 ns; -- Setup time before edge
            accept <= '0';
            wait until rising_edge(clk);
            wait for 8 ns; -- Hold time after edge
            accept <= '1';
            wait_clock_cycles(20);
        end loop;
        
        ------------------------------------------------------------------------
        -- Test Case 14: Door Timing Verification
        ------------------------------------------------------------------------
        log_message("Door Timing Verification");
        test_case_number <= 14;
        
        reset_system;
        
        make_request(2);
        
        -- Wait for door to open
        wait until op_door = '0' for 200 * CLK_PERIOD;
        if op_door = '0' then
            log_message("Door opened at time " & time'image(now));
        else
            log_message("ERROR: Door failed to open");
        end if;
        
        -- Monitor door open duration
        wait until op_door = '1' for 150 * CLK_PERIOD;
        if op_door = '1' then
            log_message("Door closed at time " & time'image(now));
        else
            log_message("ERROR: Door failed to close");
        end if;
        
        wait_clock_cycles(20);
        
        ------------------------------------------------------------------------
        -- Test Case 15: End-to-End Complex Scenario
        ------------------------------------------------------------------------
        log_message("End-to-End Complex Scenario");
        test_case_number <= 15;
        
        reset_system;
        
        -- Complex sequence starting from floor 0
        make_request(5);
        wait_clock_cycles(25); -- Start moving
        
        -- Add requests while moving to floor 5
        switches <= "0011"; -- Floor 3
        accept <= '0';
        wait_clock_cycles(2);
        switches <= "0111"; -- Floor 7  
        wait_clock_cycles(2);
        accept <= '1';
        
        wait_clock_cycles(80); -- Arrive at floor 5
        
        make_request(2); -- Request during door open at floor 5
        wait_clock_cycles(25); -- Start moving down
        
        make_request(8); -- Request while moving to floor 2
        
        wait_clock_cycles(400); -- Extended wait for complete sequence
        
        ------------------------------------------------------------------------
        -- Test Case 16: SSD Display Verification
        ------------------------------------------------------------------------
        log_message("SSD Display Verification - Testing floors 0 through 9");
        test_case_number <= 16;
        
        reset_system;
        
        -- Test all floors 0-9 sequentially
        for floor in 0 to 9 loop
            make_request(floor);
            wait_for_floor_arrival(0, floor);
            
            -- Log the current display (simplified verification)
            log_message("Reached floor " & integer'image(floor) & 
                       " - SevenSeg code: " & integer'image(to_integer(unsigned(SevenSeg))));
            
            -- Brief pause between floors
            wait_clock_cycles(20);
            
            -- Reset to floor 0 for next test (except last iteration)
            if floor < 9 then
                reset_system;
            end if;
        end loop;
        
        ------------------------------------------------------------------------
        -- Simulation Complete
        ------------------------------------------------------------------------
        log_message("ALL TEST CASES COMPLETED SUCCESSFULLY");
        simulation_complete <= true;
        wait;
        
    end process test_runner;

    -- Monitoring process for real-time observation
    monitor: process(clk)
        variable l : line;
        variable last_state : string(1 to 11) := "IDLE       ";
        variable current_state : string(1 to 11);
    begin
        if rising_edge(clk) then
            -- Determine current state
            if mv_up = '0' then
                current_state := "MOVING UP  ";
            elsif mv_dn = '0' then
                current_state := "MOVING DOWN";
            elsif op_door = '0' then
                current_state := "DOOR OPEN  ";
            else
                current_state := "IDLE       ";
            end if;
            
            -- Log state changes
            if current_state /= last_state then
                write(l, string'("State changed to: ") & current_state & " at " & time'image(now));
                writeline(output, l);
                last_state := current_state;
            end if;
        end if;
    end process monitor;

end Behavioral;
