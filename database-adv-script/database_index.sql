-- database_index.sql
-- Indexes for Users table
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_name ON users(name);
CREATE INDEX idx_users_created_at ON users(created_at);

-- Indexes for Bookings table
CREATE INDEX idx_bookings_user_id ON bookings(user_id);
CREATE INDEX idx_bookings_property_id ON bookings(property_id);
CREATE INDEX idx_bookings_check_in ON bookings(check_in);
CREATE INDEX idx_bookings_check_out ON bookings(check_out);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_user_property ON bookings(user_id, property_id);
CREATE INDEX idx_bookings_dates ON bookings(check_in, check_out);

-- Indexes for Properties table
CREATE INDEX idx_properties_price ON properties(price);
CREATE INDEX idx_properties_location ON properties(location);
CREATE INDEX idx_properties_host_id ON properties(host_id);
CREATE INDEX idx_properties_is_active ON properties(is_active);
CREATE INDEX idx_properties_price_location ON properties(price, location);

-- Indexes for Reviews table
CREATE INDEX idx_reviews_property_id ON reviews(property_id);
CREATE INDEX idx_reviews_booking_id ON reviews(booking_id);
CREATE INDEX idx_reviews_rating ON reviews(rating);
CREATE INDEX idx_reviews_created_at ON reviews(created_at);
CREATE INDEX idx_reviews_property_rating ON reviews(property_id, rating);

-- Composite indexes for common query patterns
CREATE INDEX idx_bookings_user_date ON bookings(user_id, check_in);
CREATE INDEX idx_properties_host_status ON properties(host_id, is_active);
CREATE INDEX idx_reviews_property_date ON reviews(property_id, created_at);


