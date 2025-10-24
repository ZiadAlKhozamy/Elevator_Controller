library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity RequestResolver is
    port(
        Reqs: in std_logic_vector(3 downto 0);
        clk: in std_logic;
        current_floor: in std_logic_vector(3 downto 0);
        past_state: in state_reg
    );
end RequestResolver

--  ---------------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
entity ElevatorController is 
    generic(n :integer :=10);
    -- maximum floor number is 16 
port(
    clk: in std_logic;
    rst: in std_logic;
    keys:in std_logic_vector(3 downto 0);
    mv_up: out std_logic;
    mv_dn: out std_logic;
    door_open: out std_logic;
    current_floor: out std_logic_vector(3 downto 0)
);
end ElevatorController;

architecture ElevController of ElevatorController is
TYPE ram_type IS ARRAY(0 TO n-1) of std_logic;
SIGNAL ReqFloors : ram_type := (OTHERS => '0') ;
TYPE state_type is (idle,move_up,move_down,door_open);
SIGNAL state_reg,state_next : state_type;
component RequestResolver is
    port(
     
    );
end component;
begin
    --TODO:  process of taking inputs and saving them to the memory
    

    --TODO: process of updating the state to next_state on the clock edge
    

    --TODO: handle each state logic depneding on the Request resolver 
    
end architecture ElevController;



