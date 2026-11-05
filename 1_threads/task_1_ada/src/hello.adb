with Ada.Text_IO; use Ada.Text_IO;

procedure Hello is

   Buffer_Size : constant := 5;

   type Index is mod Buffer_Size;
   type Item_Array is array (Index) of Integer;

   --  Защищённый кольцевой буфер ограниченного размера
   protected Buffer is
      entry Put (Item : in Integer);
      entry Get (Item : out Integer);
   private
      Data  : Item_Array := (others => 0);
      Head  : Index := 0;
      Tail  : Index := 0;
      Count : Natural := 0;
   end Buffer;

   protected body Buffer is

      entry Put (Item : in Integer) when Count < Buffer_Size is
      begin
         Data (Tail) := Item;
         Tail  := Tail + 1;
         Count := Count + 1;
      end Put;

      entry Get (Item : out Integer) when Count > 0 is
      begin
         Item  := Data (Head);
         Head  := Head + 1;
         Count := Count - 1;
      end Get;

   end Buffer;

   task type Producer (ID : Positive; Items : Positive);
   task type Consumer (ID : Positive; Items : Positive);

   task body Producer is
      Value : Integer;
   begin
      for I in 1 .. Items loop
         Value := ID * 100 + I;
         Buffer.Put (Value);
         Put_Line ("Producer" & Positive'Image (ID) &
                   " put" & Integer'Image (Value));
         delay 0.05;
      end loop;
      Put_Line ("Producer" & Positive'Image (ID) & " finished");
   end Producer;

   task body Consumer is
      Value : Integer;
      Sum   : Integer := 0;
   begin
      for I in 1 .. Items loop
         Buffer.Get (Value);
         Sum := Sum + Value;
         Put_Line ("    Consumer" & Positive'Image (ID) &
                   " got" & Integer'Image (Value));
         delay 0.12;
      end loop;
      Put_Line ("Consumer" & Positive'Image (ID) &
                " finished, sum =" & Integer'Image (Sum));
   end Consumer;

   --  Задачи стартуют автоматически при создании объектов
   P1 : Producer (ID => 1, Items => 5);
   P2 : Producer (ID => 2, Items => 5);
   C1 : Consumer (ID => 1, Items => 5);
   C2 : Consumer (ID => 2, Items => 5);

begin
   --  Главная процедура дожидается завершения всех задач
   Put_Line ("Main: tasks started");
end Hello;
