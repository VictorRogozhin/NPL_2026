create table customers (
  id INT,
  name VARCHAR(100),
  primary key (id)
);
CREATE TABLE orders (
  id INT PRIMARY KEY,
  customer_id INT,
  total DECIMAL(10, 2),
  FOREIGN KEY (customer_id) REFERENCES customers (id)
);
CREATE TABLE shipments (
  order_id INT,
  FOREIGN KEY (order_id) REFERENCES orders (id)
);
CREATE TABLE categories (id INT PRIMARY KEY);
