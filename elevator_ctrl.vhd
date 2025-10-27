library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SSD is
    port(
	current_floor: in std_logic_vector(3 downto 0);
	SSD_Out: out std_logic_vector(6 downto 0)
    );
   
end SSD;

architecture SSD_Architecture of SSD is
begin
    process(current_floor)
    begin
        case current_floor is
            when "0000" =>
                SSD_Out <= "1111110";
            when "0001" =>
                SSD_Out <= "0110000";
            when "0010" =>
                SSD_Out <= "1101101";
            when "0011" =>
                SSD_Out <= "1111001";
            when "0100" =>
                SSD_Out <= "0110011";
            when "0101" =>
                SSD_Out <= "1011011";
            when "0110" =>
                SSD_Out <= "1011111";
            when "0111" =>
                SSD_Out <= "1110000";
            when "1000" =>
                SSD_Out <= "1111111";
            when "1001" =>
                SSD_Out <= "1111011";
            when others =>
                SSD_Out <= "0000001";
        end case;
    end process;
end SSD_Architecture;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity RequestResolver is
    generic(n:integer :=10);
    port(
        Reqs: in std_logic_vector(n-1 downto 0);
        current_floor: in std_logic_vector(3 downto 0);
		resolved_request: out std_logic_vector(3 downto 0)
    );
end RequestResolver;

architecture RequestResolverArchitecture of RequestResolver is
	type past_state_type is (move_up,move_down);
	signal past_state: past_state_type:= move_down;
begin
    process(Reqs, current_floor, past_state)
		variable current_floor_int : integer;
        variable target_floor : integer:= 0;
    begin
        current_floor_int := to_integer(unsigned(current_floor));
        target_floor := current_floor_int;

        if past_state = move_up then 
            for i in current_floor_int+1 to n-1 loop
                if Reqs(i) = '1' then
                    target_floor := i;
                    exit;
                end if;
            end loop;
            if target_floor = current_floor_int then
                for i in  current_floor_int-1  downto 0 loop
                    if Reqs(i) = '1' then
                        target_floor := i;
						past_state <= move_down;
                        exit;
                    end if;
                end loop;
            end if;
        else
            for i in current_floor_int-1  downto 0 loop
                if Reqs(i) = '1' then
                    target_floor := i;
                    exit;
                end if;
            end loop;
            if target_floor = current_floor_int then
                for i in current_floor_int+1 to n-1 loop
                    if Reqs(i) = '1' then
                        target_floor := i;
						past_state <= move_up;
                        exit;
                    end if;
                end loop;
            end if;
        end if;
        resolved_request <= std_logic_vector(to_unsigned(target_floor, 4));
    end process;
end RequestResolverArchitecture;
				
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
    switches:in std_logic_vector(3 downto 0);
    -- there are 4 switches
    accept: in std_logic;  
    --!  accepts button is used to accept the input entered by switches
    mv_up: out std_logic;
    mv_dn: out std_logic;
    op_door: out std_logic;
    SevenSeg: out std_logic_vector(6 downto 0)
    -- ;CurrentFloor: out std_logic_vector(3 downto 0)
);
end ElevatorController;

architecture ElevController of ElevatorController is
-- TYPE ram_type IS ARRAY(0 TO n-1) of std_logic;
-- SIGNAL ReqFloors : ram_type := (OTHERS => '0') ;
SIGNAL ReqFloors : std_logic_vector(n-1 downto 0) := (n-1 downto 0 =>'0');
--  the ReqFloors will be given to the Request resolver as a vector with 1 in the floors we need
TYPE state_type is (idle,move_up,move_down,door_open);
SIGNAL state_reg,state_next : state_type := idle;
SIGNAL processed_request: std_logic_vector(3 downto 0);
SIGNAL current_floor: std_logic_vector(3 downto 0):= "0000";
-- SIGNAL ResolverState :std_logic_vector(1 downto 0);
--  00 for idle
--  01 for movingup
--  10 for moving down
--  if needed 11 for door_open
SIGNAL CLK1Sec: std_logic;
SIGNAL enableCounter:std_logic:='0';
SIGNAL door_closed:std_logic:='0';
SIGNAL SSD_Out: std_logic_vector (6 downto 0);
component RequestResolver is
    generic(n:integer :=10);
    port(
        Reqs: in std_logic_vector(n-1 downto 0);
        current_floor: in std_logic_vector(3 downto 0);
		resolved_request: out std_logic_vector(3 downto 0)
    );
end component;
component Counter2Sec is
    port(
        clk:in std_logic;
        enable:in std_logic;
        CLKOUT1Sec: out std_logic
    );
end component;
component SSD is
    port(
	current_floor: in std_logic_vector(3 downto 0);
	SSD_Out: out std_logic_vector(6 downto 0)
    );
end component;

begin

    -- CurrentFloor<=current_floor;
resolver: RequestResolver generic map (n => n) port map(ReqFloors,current_floor,processed_request);
display: SSD port map(current_floor,SSD_Out);
SevenSeg<=SSD_Out;

--------------------
    -- process of updating the state to next_state on the clock edge
    --// state register 
    process(clk)
    begin
        if(rising_edge(clk)) then
            state_reg<=state_next;
        end if;
    end process;
   

    -- process of taking inputs and saving them to the memory(vector signal to be able to access it from other entities if needed)
    process(accept,rst,door_closed)
    begin 
        if(accept='1') then
            ReqFloors(to_integer(unsigned(switches)))<='1';
        elsif(rst='1') then 
            ReqFloors<=(others=>'0');
        end if;
        if(door_closed='1' and state_reg=door_open) then
        ReqFloors( to_integer(unsigned(current_floor)) ) <= '0';  
        end if;

        
    end process;

    -- handle each state logic depneding on the Request resolver outputs (processed request ,noReq )
    --noReq is a flag determining whether there is a request or not
    process(processed_request,state_reg,current_floor,door_closed)
    begin 
        mv_up<='0';
        mv_dn<='0';
        op_door<='0';
       -- enableCounter<='0';
    case state_reg is 
        when idle =>
       
            if(to_integer(unsigned(processed_request)) > to_integer(unsigned(current_floor))) then
                mv_up <= '1';
                state_next <= move_up;
                enableCounter<='1';
            elsif(to_integer(unsigned(processed_request)) < to_integer(unsigned(current_floor))) then
                mv_dn <= '1';
                state_next <= move_down;
                enableCounter<='1';
            else enableCounter<='0';
            end if;
        

        when move_up =>
            if(to_integer(unsigned(processed_request)) /= to_integer(unsigned(current_floor)) ) then
                state_next <= move_up;
                mv_up <= '1';
            else 
                state_next <= door_open;
                op_door<='1';
            end if;
        enableCounter<='1';

        when move_down =>
        if(to_integer(unsigned(processed_request)) /= to_integer(unsigned(current_floor))) then
            state_next <= move_down;
            mv_dn<='1';
        else 
            state_next <= door_open;
            op_door<='1';
            end if;
        enableCounter<='1';

        when door_open =>
         op_door<='1';
         if(door_closed='1') then 
         state_next<=idle;
        -- ReqFloors( to_integer(unsigned(current_floor)) ) <= '0';
         end if;
        --Wait two seconds then go to idle ==> happens in a following process

    end case;
    end process;
    
    process(CLK1Sec)
    begin 
       if(falling_edge(CLK1Sec)) then
           if(state_reg = door_open) then
            door_closed<='1';
           
       elsif(state_reg = move_up) then
           current_floor<=std_logic_vector( to_unsigned( to_integer(unsigned(current_floor)) + 1, 4 ) );
           door_closed<='0';
        elsif(state_reg = move_down) then
            current_floor<=std_logic_vector( to_unsigned( to_integer(unsigned(current_floor)) - 1, 4 ) );
            door_closed<='0';
       end if;
end if;
    end process;

 counter:Counter2Sec port map(clk,enableCounter,CLK1Sec);
end architecture ElevController;



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
entity Counter2Sec is
    port(
        clk:in std_logic;
        enable:in std_logic;
        CLKOUT1Sec: out std_logic
    );
end Counter2Sec;

architecture count of Counter2Sec is
    SIGNAL CLK1Sec :std_logic := '0';
    SIGNAL CounterReg:unsigned(25 downto 0) := (others=> '0');
    --26 bit is enough to simulate a 50 million count
begin

process(clk,CounterReg,enable)
begin
    if(falling_edge(clk) and enable='1') then
        if(to_integer(unsigned(CounterReg)) = 50) then
            CLK1Sec <= not CLK1Sec;
            CounterReg<= (0=>'1',others=>'0');
        else 
            CounterReg<=  to_unsigned( to_integer(CounterReg) + 1, 26 );
        end if;
        elsif (enable='0')then
            -- ClK1Sec<='0';
            CounterReg<= (0=>'1',others=>'0');
end if;

end process;

CLKOUT1Sec<=CLK1Sec;

end count;


