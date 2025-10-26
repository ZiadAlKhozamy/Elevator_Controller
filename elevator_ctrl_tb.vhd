library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ElevatorController_tb is
end entity;

architecture behavior of ElevatorController_tb is
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
            CurrentFloor: out std_logic_vector(3 downto 0)
        );
    end component;
    signal clk_tb          : std_logic := '0';
    signal rst_tb          : std_logic := '0';
    signal switches_tb     : std_logic_vector(3 downto 0) := (others => '0');
    signal accept_tb       : std_logic := '0';
    signal mv_up_tb        : std_logic;
    signal mv_dn_tb        : std_logic;
    signal op_door_tb      : std_logic;
    signal CurrentFloor_tb : std_logic_vector(3 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin
    DUT: ElevatorController
        generic map(n => 10)
        port map(
            clk => clk_tb,
            rst => rst_tb,
            switches => switches_tb,
            accept => accept_tb,
            mv_up => mv_up_tb,
            mv_dn => mv_dn_tb,
            op_door => op_door_tb,
            CurrentFloor => CurrentFloor_tb
        );

    clk_process : process
    begin
        while true loop
            clk_tb <= '0';
            wait for CLK_PERIOD / 2;
            clk_tb <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;
    stim_proc : process
    begin
        rst_tb <= '1';
        wait for 20 ns;
        rst_tb <= '0';
        report "System Reset complete. Starting test cases.";

        switches_tb <= "0011";
        accept_tb <= '1'; wait for CLK_PERIOD; accept_tb <= '0';
        report "Test 1: Request for floor 3 submitted.";
        wait for 200 ns;
          
        switches_tb <= "0010";
        accept_tb <= '1'; wait for CLK_PERIOD; accept_tb <= '0';
        report "Test 2: Request for floor 2 submitted.";
        wait for 200 ns;

        switches_tb <= "0010"; accept_tb <= '1'; wait for CLK_PERIOD; accept_tb <= '0'; wait for 10 ns;
        switches_tb <= "0100"; accept_tb <= '1'; wait for CLK_PERIOD; accept_tb <= '0'; wait for 10 ns;
        switches_tb <= "0110"; accept_tb <= '1'; wait for CLK_PERIOD; accept_tb <= '0';
        report "Test 3: Multiple upward requests (2,4,6).";
        wait for 300 ns;

        switches_tb <= "0111"; accept_tb <= '1'; wait for CLK_PERIOD; accept_tb <= '0'; wait for 10 ns;
        switches_tb <= "0010"; accept_tb <= '1'; wait for CLK_PERIOD; accept_tb <= '0';
        report "Test 4: Requests for floor 7 and 2 submitted.";
        wait for 300 ns;

        report "Test 5: System idle. No new requests.";
        wait for 200 ns;

        switches_tb <= "1001"; accept_tb <= '1'; wait for CLK_PERIOD; accept_tb <= '0';  -- Floor 9
        report "Test 6a: Request for top floor (9).";
        wait for 200 ns;

        switches_tb <= "0000"; accept_tb <= '1'; wait for CLK_PERIOD; accept_tb <= '0';  -- Floor 0
        report "Test 6b: Request for ground floor (0).";
        wait for 200 ns;

        report "All test cases complete." severity note;
        wait;
    end process;

end architecture;
