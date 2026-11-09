with Ada.Text_IO; use Ada.Text_IO;

procedure Main is
   type Storage is array (1 .. 5) of Integer;
   protected Buffer is
      entry Put (Value : Integer);
      entry Get (Value : out Integer);
   private
      Data : Storage := [others => 0];
      Head, Tail : Positive := 1;
      Count : Natural := 0;
   end Buffer;
   protected body Buffer is
      entry Put (Value : Integer) when Count < 5 is
      begin
         Data (Tail) := Value;
         Tail := Tail mod 5 + 1;
         Count := Count + 1;
      end Put;
      entry Get (Value : out Integer) when Count > 0 is
      begin
         Value := Data (Head);
         Head := Head mod 5 + 1;
         Count := Count - 1;
      end Get;
   end Buffer;

   type Totals is array (1 .. 2) of Natural;
   Results : Totals := [others => 0];
   Counts : Totals := [others => 0];
   task type Producer (Id : Positive) is
      entry Finished;
   end Producer;
   task body Producer is
   begin
      for I in 1 .. 10 loop
         Buffer.Put ((Id - 1) * 10 + I);
         delay 0.03;
      end loop;
      accept Finished;
   end Producer;
   task type Consumer (Id : Positive);
   task body Consumer is
      Value, Sum, Received : Integer := 0;
   begin
      loop
         Buffer.Get (Value);
         exit when Value = 0;
         Sum := Sum + Value;
         Received := Received + 1;
         delay 0.05;
      end loop;
      Results (Id) := Sum;
      Counts (Id) := Received;
      Put_Line ("Consumer" & Id'Image & ": count =" & Received'Image
                & ", sum =" & Sum'Image);
   end Consumer;
begin
   Put_Line ("Two producers, two consumers; buffer capacity = 5");
   declare
      P1 : Producer (1);
      P2 : Producer (2);
      C1 : Consumer (1);
      C2 : Consumer (2);
   begin
      P1.Finished;
      P2.Finished;
      -- Both producers finished: enqueue one stop marker per consumer.
      Buffer.Put (0);
      Buffer.Put (0);
   end; -- Wait for all four dependent tasks before reading results.
   Put_Line ("Total count =" & Integer'Image (Counts (1) + Counts (2)));
   Put_Line ("Total sum =" & Integer'Image (Results (1) + Results (2)));
   if Counts (1) + Counts (2) /= 20 or Results (1) + Results (2) /= 210 then
      raise Program_Error with "Unexpected result";
   end if;
   Put_Line ("CHECK PASSED: 20 values, expected sum = 210");
end Main;
