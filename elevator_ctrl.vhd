
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
        when "0000" => SSD_Out <= "1000000";      
        when "0001" => SSD_Out <= "1111001"; 
        when "0010" => SSD_Out <= "0100100"; 
        when "0011" => SSD_Out <= "0110000"; 
        when "0100" => SSD_Out <= "0011001"; 
        when "0101" => SSD_Out <= "0010010"; 
        when "0110" => SSD_Out <= "0000010"; 
        when "0111" => SSD_Out <= "1111000"; 
        when "1000" => SSD_Out <= "0000000"; 
        when "1001" => SSD_Out <= "0011000"; 
        when others => SSD_Out <= "0111111"; 
       end case;
    end process;
end SSD_Architecture;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity RequestResolver is
    generic(n:integer :=10);
    port(
        clk: in std_logic;
        Reqs: in std_logic_vector(n-1 downto 0);
        current_floor: in std_logic_vector(3 downto 0);
        resolved_request: out std_logic_vector(3 downto 0);
        IsMoving: in std_logic
    );
end RequestResolver;

architecture RequestResolverArchitecture of RequestResolver is
    type past_state_type is (move_up, move_down);
    signal past_state: past_state_type := move_down;
begin
    process(clk)
    -- process(Reqs, current_floor)
        variable current_floor_int : integer;
        variable target_floor : integer;
        variable flag:std_logic:= '0';
    begin
	 if(rising_edge(clk)) then
        current_floor_int := to_integer(unsigned(current_floor));
        target_floor := current_floor_int;
        flag := '0';
        if past_state = move_up then 
            --Search upwards
            flag := '0';
            for i in 0 to n-1 loop
                if i >= current_floor_int then
                    if IsMoving = '1' and i = current_floor_int then
                        next;
                    end if;
                    if Reqs(i) = '1' then
                        target_floor := i;
                        exit;
                    end if;
                end if;
            end loop;
            
            for i in 0 to n-1 loop
                if i > current_floor_int then
                    flag := flag or Reqs(i);
                end if;
            end loop;
            if flag = '0' then
                -- Search downwards
                for i in n-1 downto 0 loop
                    if i <= current_floor_int then
                        if IsMoving = '1' and i = current_floor_int then
                            next;
                        end if;
                        if Reqs(i) = '1' then
                            target_floor := i;
                            past_state <= move_down;
                            exit;
                        end if;
                    end if;
                end loop;
        end if;
        else
            -- Similar logic for move_down state
            flag := '0';
            for i in n-1 downto 0 loop
                if i <= current_floor_int then
                    if IsMoving = '1' and i = current_floor_int then
                        next;
                    end if;
                    if Reqs(i) = '1' then
                        target_floor := i;
                        exit;
                    end if;
                end if;
            end loop;
            for i in n-1 downto 0 loop
                if i < current_floor_int then
                    flag := flag or Reqs(i);
                end if;
            end loop; 
            if flag = '0' then
                for i in 0 to n-1 loop
                    if i >= current_floor_int then
                        if IsMoving = '1' and i = current_floor_int then
                            next;
                        end if;
                        if Reqs(i) = '1' then
                            target_floor := i;
                            past_state <= move_up;
                            exit;
                        end if;
                    end if;
                end loop;
            end if;
        end if;
        resolved_request <= std_logic_vector(to_unsigned(target_floor, 4));
   end if;
	end process;
end RequestResolverArchitecture;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ElevatorController is 
    generic(n : integer := 10);
    port(
        clk: in std_logic;
        rst: in std_logic;
        switches: in std_logic_vector(3 downto 0);
        accept: in std_logic;  
        mv_up: out std_logic;
        mv_dn: out std_logic;
        op_door: out std_logic;
        SevenSeg: out std_logic_vector(6 downto 0)
    );
end ElevatorController;

architecture ElevController of ElevatorController is
    SIGNAL ReqFloors : std_logic_vector(n-1 downto 0) := (others => '0');
    TYPE state_type is (idle, move_up, move_down, door_open);
    SIGNAL state_reg, state_next : state_type := idle;
    SIGNAL processed_request: std_logic_vector(3 downto 0);
    SIGNAL current_floor: std_logic_vector(3 downto 0) := "0000";
    SIGNAL CLK1Sec: std_logic;
    SIGNAL enableCounter: std_logic := '0';
    SIGNAL door_closed: std_logic := '0';
    SIGNAL SSD_Out: std_logic_vector(6 downto 0);
    SIGNAL IsMoving: std_logic := '0';
    SIGNAL clear_current_floor_request: std_logic := '0';
    
    component RequestResolver is
        generic(n: integer := 10);
        port(
            clk: in std_logic;
            Reqs: in std_logic_vector(n-1 downto 0);
            current_floor: in std_logic_vector(3 downto 0);
            resolved_request: out std_logic_vector(3 downto 0);
            IsMoving: in std_logic
        );
    end component;
    
    component Counter2Sec is
        port(
            clk: in std_logic;
            enable: in std_logic;
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

    IsMoving <= '1' when state_reg = move_up or state_reg = move_down else '0';
    
    resolver: RequestResolver 
        generic map (n => n) 
        port map(
            clk => clk,
            Reqs => ReqFloors,
            current_floor => current_floor,
            resolved_request => processed_request,
            IsMoving => IsMoving
        );
        
    display: SSD port map(current_floor, SSD_Out);
    SevenSeg <= SSD_Out;

    -- State register (NO RESET - rst only affects ReqFloors)
    -- process(clk)
    -- begin
    --     if rising_edge(clk) then
    --         state_reg <= state_next;
    --     end if;
    -- end process;

    -- Request handling process (rst ONLY clears ReqFloors)
    process(clk)
    begin
        if rising_edge(clk) then
            -- Reset condition: ONLY clear ReqFloors
            state_reg <= state_next;
            if rst = '0' then
                ReqFloors <= (others => '0');
                state_reg <= idle;
            else
                -- Normal operation: set request when accept button is pressed
                if accept = '0' then
                    ReqFloors(to_integer(unsigned(switches))) <= '1';
                end if;
                
                -- Clear current floor request when door closes
                if clear_current_floor_request = '1' then
                    ReqFloors(to_integer(unsigned(current_floor))) <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Next state logic (NO RESET dependency)
    process(state_reg, processed_request, current_floor, door_closed)
    begin
        -- Default values to avoid latches
        state_next <= state_reg;
        mv_up <= '0';  -- Active low
        mv_dn <= '0';  -- Active low  
        op_door <= '0'; -- Active low
        -- enableCounter <= '0';
        clear_current_floor_request <= '0';
        
        case state_reg is 
            when idle =>
                if to_integer(unsigned(processed_request)) > to_integer(unsigned(current_floor)) then
                    mv_up <= '1';
                    state_next <= move_up;
                    enableCounter <= '1';
                elsif to_integer(unsigned(processed_request)) < to_integer(unsigned(current_floor)) then
                    mv_dn <= '1';
                    state_next <= move_down;
                    enableCounter <= '1';
                end if;
                
            when move_up =>
                enableCounter <= '1';
                if to_integer(unsigned(processed_request)) = to_integer(unsigned(current_floor)) then
                    state_next <= door_open;
                    op_door <= '1';
                else
                    state_next <= move_up;
                    mv_up <= '1';
                end if;
                
            when move_down =>
                enableCounter <= '1';
                if to_integer(unsigned(processed_request)) = to_integer(unsigned(current_floor)) then
                    state_next <= door_open;
                    op_door <= '1';
                else
                    state_next <= move_down;
                    mv_dn <= '1';
                end if;
                
            when door_open =>
                op_door <= '1';
                if door_closed = '1' then 
                    state_next <= idle;
                    clear_current_floor_request <= '1';
                end if;
        end case;
    end process;
    
    -- Floor movement and door timing (NO RESET)
   
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

    counter: Counter2Sec port map(clk, enableCounter, CLK1Sec);
    
end architecture ElevController;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Counter2Sec is
    port(
        clk: in std_logic;
        enable: in std_logic;
        CLKOUT1Sec: out std_logic
    );
end Counter2Sec;

architecture count of Counter2Sec is
    SIGNAL CLK1Sec : std_logic := '0';
    SIGNAL CounterReg: unsigned(25 downto 0) := (others => '0');
    constant MAX_COUNT : integer := 50000000; -- 1 second at 50MHz
begin

    process(clk, enable)
    begin
        if enable = '0' then
            CLK1Sec <= '0';
            CounterReg <= (others => '0');
        elsif falling_edge(clk) then
            if CounterReg = MAX_COUNT - 1 then
                CLK1Sec <= not CLK1Sec;
                CounterReg <= (others => '0');
            else 
                CounterReg <= CounterReg + 1;
            end if;
        end if;
    end process;

    CLKOUT1Sec <= CLK1Sec;

end count;