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
    swtiches:in std_logic_vector(3 downto 0);
    -- there are 4 switches
    accept: in std_logic;  
    --!  accepts button is used to accept the input entered by switches
    mv_up: out std_logic;
    mv_dn: out std_logic;
    op_door: out std_logic;
    current_floor: out std_logic_vector(3 downto 0)
);
end ElevatorController;

architecture ElevController of ElevatorController is
-- TYPE ram_type IS ARRAY(0 TO n-1) of std_logic;
-- SIGNAL ReqFloors : ram_type := (OTHERS => '0') ;
SIGNAL ReqFloors : std_logic_vector(n-1 downto 0) := (n-1 downto 0 =>'0');
--  the ReqFloors will be given to the Request resolver as a vector with 1 in the floors we need
TYPE state_type is (idle,move_up,move_down,door_open);
SIGNAL state_reg,state_next : state_type := idle;
SIGNAL ResolverState :std_logic_vector(1 downto 0);
--  00 for idle
--  01 for movingup
--  10 for moving down
--  if needed 11 for door_open
SIGNAL CLK1Sec: std_logic;
SIGNAL enableCounter:std_logic:='0';
component RequestResolver is
    port(
     
    );
end component;
begin

    -- Some initialized output values (may be removed)
    process 
    begin
    current_floor<="0000";
    op_door<='0';
    noReq<='1';
    --  this is to be removed
    end process

    -- process of updating the state to next_state on the clock edge
    --// state register 
    process(clk)
    begin
        if(rising_edge(clk)) then
            state_reg<=state_next;
        end if;
    end process;
   

    -- process of taking inputs and saving them to the memory(vector signal to be able to access it from other entities if needed)
    process(accept)
    begin 
        if(rising_edge(accept)) then
            ReqFloors(to_integer(unsigned(switches)))<='1';
        end if;
    end process;

    -- handle each state logic depneding on the Request resolver outputs (processed request ,noReq )
    --noReq is a flag determining whether there is a request or not
    process(processed_request,noReq,state_reg,current_floor)
    begin 
        mv_up<='0';
        mv_down<='0';
        op_door<='0';
        enable<='0';
    case state_reg is 
        when idle =>
        if(noReq = '0') then
            if(processed_request > current_floor) then
                mv_up <= '1';
                state_next <= move_up;
            elsif(processed_request > current_floor) then
                mv_down <= '1';
                state_next <= move_down;
            end if;
        end if;

        when move_up =>
            if(processed_request != current_floor) then
            state_next <= move_up;
             mv_up <= '1';
            else 
                state_next <= door_open;
                op_door<='1';
            end if;
        enable<='1';

        when move_down =>
        if(processed_request != current_floor) then
            state_next <= move_down;
            mv_down<='1';
        else 
            state_next <= door_open;
            op_door<='1';
            end if;
        enable<='1';

        when door_open =>
         enable<='1';
        --Wait two seconds then go to idle ==> happens in a following process

    end case;
    end process;
    
    process(CLK1Sec)
    begin 
       if(falling_edge(CLK1Sec)) then
           if(state_reg = door_open)
           state_next<=idle;
       elsif(state_reg = move_up)
           current_floor<=current_floor+1;
       elsif(state_reg = move_down)
           current_floor<=current_floor-1;
       end if;
    end process;

 counter:Counter2Sec port map(clk,enable,CLK1Sec);
end architecture ElevController;



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
entity Counter2Sec is
    port(
        clk:in std_logic;
        enable:in std_logic;
        CLKOUT1Sec: out std_logic;
    );
end Counter;

architecture count of Counter2Sec is
    SIGNAL CLK1Sec :std_logic := '0';
    SIGNAL CounterReg:unsinged(25 downto 0) := (others=> '0');
    --26 bit is enough to simulate a 50 million count
begin

process(clk,CounterReg,enable)
begin
    if(falling_edge(clk) and enable=1) then
    if(CounterReg=50000000) then
        CLK1Sec <= not CLK1Sec;
        CounterReg<= (0=>'1',others=>'0');
    else 
    CounterReg<= CounterReg+1; 
    end if;
    elsif (enable=0)then
        CounterReg<= (0=>'1',others=>'0');
end if;

end process

CLKOUT1Sec<=CLK1Sec;

end count;
