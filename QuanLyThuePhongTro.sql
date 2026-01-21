-- =====================================================
-- HỆ THỐNG QUẢN LÝ THUÊ PHÒNG TRỌ - THANHTHAO STAY
-- =====================================================
CREATE DATABASE QuanLyThuePhongTro;
GO
USE QuanLyThuePhongTro;
GO

-- =====================================================
-- 0. BẢNG ADDRESSES (Địa chỉ)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ tập trung thông tin địa chỉ để tránh lặp lại
-- - Được tham chiếu bởi: Users (địa chỉ của người dùng), Rooms (địa chỉ phòng trọ)
-- - Giúp chuẩn hóa dữ liệu (3NF): Nếu cùng địa chỉ sử dụng ở nhiều phòng/người, chỉ lưu 1 lần
-- - Hỗ trợ tính năng: Tìm kiếm phòng theo địa chỉ, hiển thị bản đồ (Latitude/Longitude)
-- QUAN HỆ: 1 Addresses có thể được dùng bởi nhiều Users hoặc nhiều Rooms
CREATE TABLE Addresses (
    AddressID INT PRIMARY KEY IDENTITY(1,1),   -- Mã địa chỉ, khóa chính, tự tăng bắt đầu từ 1
    Street NVARCHAR(255) NOT NULL,             -- Đường, bắt buộc nhập
    Ward NVARCHAR(100) NOT NULL,               -- Phường/Xã, bắt buộc nhập
    District NVARCHAR(100) NOT NULL,           -- Quận/Huyện, bắt buộc nhập
    City NVARCHAR(100) NOT NULL,               -- Thành phố, bắt buộc nhập
    Province NVARCHAR(100),                    -- Tỉnh/Thành, có thể để trống
    ZipCode NVARCHAR(20),                      -- Mã bưu chính, có thể để trống
    Latitude DECIMAL(9,6),                     -- Vĩ độ, để hiển thị bản đồ
    Longitude DECIMAL(9,6),                    -- Kinh độ, để hiển thị bản đồ
    CreatedAt DATETIME DEFAULT GETDATE()       -- Ngày tạo, mặc định là thời điểm hiện tại
);
GO

-- =====================================================
-- 1. BẢNG USERS (Người dùng)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ thông tin người dùng hệ thống
-- - Role BIT: 0 = Admin (chủ phòng), 1 = User (người thuê)
-- - Hỗ trợ chức năng: Đăng nhập, đăng ký, quản lý hồ sơ, xác thực email
-- - Theo dõi: LastLoginAt để ghi nhân hoạt động cuối cùng
-- - Liên kết địa chỉ: Mỗi user có AddressID tham chiếu tới Addresses
-- - IsActive: Để khóa/mở khóa tài khoản khi vi phạm quy định
-- - IsEmailVerified: Để kiểm tra email đã xác thực hay chưa trước khi cho phép các hoạt động
-- QUAN HỆ: 1 User có thể là Admin quản lý nhiều Rooms, hoặc User thuê nhiều Bookings
CREATE TABLE Users (
    UserID INT PRIMARY KEY IDENTITY(1,1),      -- Mã người dùng, khóa chính, tự tăng
    Username NVARCHAR(50) UNIQUE NOT NULL,     -- Tên đăng nhập, duy nhất, bắt buộc
    Email NVARCHAR(100) UNIQUE NOT NULL,       -- Email, duy nhất, bắt buộc
    PasswordHash NVARCHAR(255) NOT NULL,       -- Mật khẩu được mã hóa (bcrypt), bắt buộc
    FirstName NVARCHAR(100),                   -- Họ, có thể để trống
    LastName NVARCHAR(100),                    -- Tên, có thể để trống
    PhoneNumber NVARCHAR(20),                  -- Số điện thoại, có thể để trống
    Role BIT NOT NULL, -- 0 = Admin, 1 = User  -- Vai trò: 0 là Admin/chủ phòng, 1 là User/người thuê, bắt buộc
    Avatar NVARCHAR(500),                      -- Đường dẫn ảnh đại diện, có thể để trống
    AddressID INT, -- Khóa ngoài đến Addresses -- Mã địa chỉ, tham chiếu bảng Addresses, có thể để trống
    IsActive BIT DEFAULT 1,                    -- Trạng thái hoạt động (1=hoạt động, 0=bị khóa), mặc định 1
    IsEmailVerified BIT DEFAULT 0,             -- Trạng thái xác thực email (1=đã xác thực, 0=chưa), mặc định 0
    CreatedAt DATETIME DEFAULT GETDATE(),      -- Ngày tạo, mặc định là thời điểm hiện tại
    UpdatedAt DATETIME DEFAULT GETDATE(),      -- Ngày cập nhật lần cuối, mặc định là thời điểm hiện tại
    LastLoginAt DATETIME,                      -- Lần đăng nhập cuối cùng, có thể để trống
    CONSTRAINT CK_Role CHECK (Role IN (0, 1)), -- Ràng buộc kiểm tra: Role chỉ được là 0 hoặc 1
    CONSTRAINT FK_Users_Address FOREIGN KEY (AddressID) REFERENCES Addresses(AddressID) -- Khóa ngoài: AddressID tham chiếu Addresses
);
GO

-- =====================================================
-- 2. BẢNG ROOM_STATUSES (Trạng thái phòng)
-- =====================================================
-- CHỨC NĂNG: Bảng lookup (tham chiếu) để lưu trữ các trạng thái phòng
-- - Giúp chuẩn hóa: Thay vì lưu text trực tiếp, dùng StatusID (con số) để tham chiếu
-- - Các trạng thái:
--   * StatusID = 1: Available (Có sẵn) - Phòng trống, sẵn sàng cho thuê
--   * StatusID = 2: Rented (Đã cho thuê) - Phòng đang được thuê (phải có CurrentTenantID)
--   * StatusID = 3: Maintenance (Bảo trì) - Phòng đang bảo trì, không cho thuê
--   * StatusID = 4: Reserved (Đã đặt) - Phòng đã được đặt, chờ xác nhận (CurrentTenantID = NULL)
-- - Cách hoạt động: Khi tạo phòng mới, StatusID = 1 (Available); khi booking được duyệt, trigger sẽ cập nhật StatusID = 2
-- QUAN HỆ: Được tham chiếu bởi bảng Rooms (thông qua FK_Rooms_Status)
CREATE TABLE RoomStatuses (
    StatusID INT PRIMARY KEY IDENTITY(1,1),    -- Mã trạng thái, khóa chính, tự tăng
    StatusName NVARCHAR(50) UNIQUE NOT NULL,   -- Tên trạng thái (Available, Rented, Maintenance, Reserved), duy nhất
    Description NVARCHAR(255)                  -- Mô tả chi tiết trạng thái, có thể để trống
);
GO

-- =====================================================
-- 3. BẢNG UTILITIES (Tiện ích)
-- =====================================================
-- CHỨC NĂNG: Bảng lookup để lưu danh sách các tiện ích phòng
-- - Các tiện ích có sẵn: WiFi, Điều hòa, Tủ lạnh, Giường, Bàn làm việc, Phòng tắm riêng, Bếp, Máy giặt, TV, Bảo mật 24/7
-- - Icon: Hỗ trợ hiển thị icon giao diện người dùng
-- - Cách hoạt động: 
--   * Admin chọn tiện ích khi tạo phòng mới
--   * Lưu trữ liên kết trong bảng RoomUtilities (bảng trung gian n-n)
--   * User có thể lọc phòng theo tiện ích cần thiết
-- QUAN HỆ: Được tham chiếu bởi bảng RoomUtilities (liên kết nhiều-nhiều với Rooms)
CREATE TABLE Utilities (
    UtilityID INT PRIMARY KEY IDENTITY(1,1),   -- Mã tiện ích, khóa chính, tự tăng
    UtilityName NVARCHAR(100) UNIQUE NOT NULL, -- Tên tiện ích (WiFi, AC, Fridge, v.v.), duy nhất
    Description NVARCHAR(255)                  -- Mô tả chi tiết tiện ích, có thể để trống
);
GO

-- =====================================================
-- 4. BẢNG ROOMS (Phòng trọ)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ thông tin phòng trọ - dữ liệu chính của hệ thống
-- - AdminID: ID của chủ phòng/quản lý quản lý phòng này
-- - AddressID: Địa chỉ phòng (tham chiếu tập trung từ bảng Addresses)
-- - StatusID: Trạng thái hiện tại (1=Available, 2=Rented, 3=Maintenance, 4=Reserved)
-- - CurrentTenantID: ID người thuê hiện tại (chỉ NOT NULL khi StatusID = 2/Rented)
-- - Price: Giá thuê tháng (đơn vị VND)
-- - Area: Diện tích phòng (m²), MaxOccupancy: Số người ở tối đa
-- - TRIGGER: TR_Rooms_ValidateStatus đảm bảo consistency:
--   * Nếu StatusID = 2 (Rented) thì CurrentTenantID PHẢI NOT NULL
--   * Nếu StatusID ≠ 2 thì CurrentTenantID PHẢI NULL
-- - Cách hoạt động:
--   1. Admin tạo phòng mới → StatusID = 1 (Available), CurrentTenantID = NULL
--   2. User đặt phòng (Booking) → chờ xác nhận
--   3. Admin duyệt Booking → Trigger tự động: StatusID = 2, CurrentTenantID = UserID
--   4. Khi booking bị từ chối/hủy → Trigger tự động: StatusID = 1, CurrentTenantID = NULL
-- QUAN HỆ: 1 Admin quản lý nhiều Rooms; 1 Room có 1 CurrentTenant (hoặc NULL); 1 Room có nhiều Bookings, RoomImages, Reviews
CREATE TABLE Rooms (
    RoomID INT PRIMARY KEY IDENTITY(1,1),      -- Mã phòng, khóa chính, tự tăng
    RoomNumber NVARCHAR(50) NOT NULL,          -- Số phòng (A101, B202, v.v.), bắt buộc
    AdminID INT NOT NULL,                      -- Mã Admin quản lý phòng, bắt buộc, tham chiếu Users
    Title NVARCHAR(200) NOT NULL,              -- Tiêu đề phòng (Phòng đẹp gần trường), bắt buộc
    Description NVARCHAR(MAX),                 -- Mô tả chi tiết phòng, có thể để trống (text dài)
    Area DECIMAL(10,2), -- Diện tích (m²)     -- Diện tích phòng (m²), có thể để trống
    Price DECIMAL(18,2) NOT NULL,              -- Giá thuê tháng (VND), bắt buộc, phải > 0
    PriceUnit NVARCHAR(20) DEFAULT 'VND/tháng', -- Đơn vị giá, mặc định 'VND/tháng'
    AddressID INT NOT NULL, -- Khóa ngoài đến Addresses -- Mã địa chỉ phòng, bắt buộc, tham chiếu Addresses
    MaxOccupancy INT, -- Số người tối đa   -- Số người ở tối đa, có thể để trống
    StatusID INT NOT NULL,                     -- Mã trạng thái phòng, bắt buộc, tham chiếu RoomStatuses
    CurrentTenantID INT, -- ID người thuê hiện tại -- Mã người thuê hiện tại (NULL nếu phòng trống), tham chiếu Users
    CreatedAt DATETIME DEFAULT GETDATE(),      -- Ngày tạo, mặc định là thời điểm hiện tại
    UpdatedAt DATETIME DEFAULT GETDATE(),      -- Ngày cập nhật lần cuối, mặc định là thời điểm hiện tại
    CONSTRAINT FK_Rooms_Admin FOREIGN KEY (AdminID) REFERENCES Users(UserID), -- FK: AdminID tham chiếu Users
    CONSTRAINT FK_Rooms_Status FOREIGN KEY (StatusID) REFERENCES RoomStatuses(StatusID), -- FK: StatusID tham chiếu RoomStatuses
    CONSTRAINT FK_Rooms_CurrentTenant FOREIGN KEY (CurrentTenantID) REFERENCES Users(UserID), -- FK: CurrentTenantID tham chiếu Users
    CONSTRAINT FK_Rooms_Address FOREIGN KEY (AddressID) REFERENCES Addresses(AddressID), -- FK: AddressID tham chiếu Addresses
    CONSTRAINT CK_Price CHECK (Price > 0),     -- Ràng buộc: Giá phòng phải > 0
    CONSTRAINT CK_Area CHECK (Area > 0)        -- Ràng buộc: Diện tích phải > 0
);
GO

-- =====================================================
-- 5. BẢNG ROOM_UTILITIES (Liên kết Phòng - Tiện ích)
-- =====================================================
-- CHỨC NĂNG: Bảng trung gian để quản lý mối quan hệ many-to-many (n-n) giữa Rooms và Utilities
-- - 1 Phòng có thể có nhiều Tiện ích (WiFi, A/C, v.v.)
-- - 1 Tiện ích có thể thuộc về nhiều Phòng
-- - CONSTRAINT UQ_RoomUtility: Đảm bảo không có bản ghi trùng lặp (cùng RoomID-UtilityID)
-- - Cách hoạt động:
--   1. Admin tạo phòng → chọn các tiện ích (tạo nhiều bản ghi RoomUtilities)
--   2. User tìm kiếm phòng → lọc theo tiện ích cần (JOIN với RoomUtilities)
--   3. Xem chi tiết phòng → hiển thị danh sách tiện ích từ RoomUtilities
-- - ON DELETE CASCADE: Khi xóa phòng, tất cả bản ghi RoomUtilities của phòng đó cũng bị xóa
-- QUAN HỆ: Nối Rooms (FK_RoomUtilities_Room) với Utilities (FK_RoomUtilities_Utility)
CREATE TABLE RoomUtilities (
    RoomUtilityID INT PRIMARY KEY IDENTITY(1,1), -- Mã tiện ích phòng, khóa chính, tự tăng
    RoomID INT NOT NULL,                         -- Mã phòng, bắt buộc, tham chiếu Rooms, xóa tầng (CASCADE)
    UtilityID INT NOT NULL,                      -- Mã tiện ích, bắt buộc, tham chiếu Utilities
    CONSTRAINT FK_RoomUtilities_Room FOREIGN KEY (RoomID) REFERENCES Rooms(RoomID) ON DELETE CASCADE, -- FK: RoomID xóa tầng
    CONSTRAINT FK_RoomUtilities_Utility FOREIGN KEY (UtilityID) REFERENCES Utilities(UtilityID),    -- FK: UtilityID tham chiếu Utilities
    CONSTRAINT UQ_RoomUtility UNIQUE (RoomID, UtilityID) -- Ràng buộc: Không trùng lặp (RoomID, UtilityID)
);
GO

-- =====================================================
-- 6. BẢNG ROOM_IMAGES (Hình ảnh phòng)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ tất cả hình ảnh của mỗi phòng
-- - 1 Phòng có thể có nhiều Hình ảnh (ảnh phòng, ảnh phòng tắm, ảnh từng góc, v.v.)
-- - DisplayOrder: Thứ tự hiển thị ảnh (1, 2, 3, ...)
-- - IsMainImage: BIT để đánh dấu ảnh chính (hiển thị ở danh sách tìm kiếm)
-- - UploadedAt: Thời gian upload để theo dõi lịch sử
-- - Cách hoạt động:
--   1. Admin tải lên 1 hoặc nhiều hình ảnh cho phòng
--   2. Hệ thống lưu file và tạo bản ghi RoomImages với DisplayOrder và IsMainImage
--   3. Giao diện hiển thị ảnh chính ở danh sách tìm kiếm
--   4. Hiển thị tất cả ảnh (sắp xếp theo DisplayOrder) khi xem chi tiết phòng
-- - ON DELETE CASCADE: Khi xóa phòng, tất cả ảnh của phòng đó cũng bị xóa
-- QUAN HỆ: Nhiều RoomImages chỉ cùng 1 Room
CREATE TABLE RoomImages (
    ImageID INT PRIMARY KEY IDENTITY(1,1),        -- Mã hình ảnh, khóa chính, tự tăng
    RoomID INT NOT NULL,                          -- Mã phòng, bắt buộc, tham chiếu Rooms, xóa tầng (CASCADE)
    ImageUrl NVARCHAR(500),                       -- Đường dẫn hình ảnh (URL), có thể để trống (NULL)
    DisplayOrder INT,                             -- Thứ tự hiển thị hình ảnh (1=đầu tiên, 2=thứ hai, v.v.), có thể để trống
    IsMainImage BIT DEFAULT 0,                    -- Hình ảnh chính (1=là, 0=không), mặc định là 0
    UploadedAt DATETIME DEFAULT GETDATE(),        -- Ngày tải lên, mặc định là thời điểm hiện tại
    CONSTRAINT FK_RoomImages_Room FOREIGN KEY (RoomID) REFERENCES Rooms(RoomID) ON DELETE CASCADE -- FK: RoomID xóa tầng
);
GO

-- =====================================================
-- 7. BẢNG BOOKINGS (Đặt phòng)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ các yêu cầu đặt phòng từ User
-- - BookingStatus: Trạng thái đơn đặt phòng
--   * 'Pending' (Chờ duyệt) - User vừa tạo, chờ Admin xác nhận
--   * 'Approved' (Duyệt) - Admin đã phê duyệt, hợp đồng tự động tạo, phòng chuyển sang Rented
--   * 'Rejected' (Từ chối) - Admin từ chối, phòng quay về Available
--   * 'Cancelled' (Hủy) - User hủy trước hoặc sau khi duyệt, phòng quay về Available
-- - CheckInDate: Ngày vào phòng
-- - Duration: Số tháng thuê
-- - DepositAmount: Tiền cọc (tính bằng VND)
-- - ApprovedBy: ID admin phê duyệt (nếu là Approved)
-- - TRIGGER: TR_Bookings_StatusUpdateRoom tự động cập nhật Room status:
--   * 'Approved' → Room.StatusID = 2 (Rented), CurrentTenantID = UserID
--   * 'Rejected' hoặc 'Cancelled' → Room.StatusID = 1 (Available), CurrentTenantID = NULL
-- - Cách hoạt động:
--   1. User xem chi tiết phòng → nhấn "Đặt phòng" → tạo booking ở trạng thái Pending
--   2. Admin xem danh sách booking chờ duyệt
--   3. Admin phê duyệt → Booking.BookingStatus = 'Approved' → Trigger tạo Contract
--   4. Hoặc Admin từ chối → Booking.BookingStatus = 'Rejected'
-- QUAN HỆ: 1 User có nhiều Bookings; 1 Room có nhiều Bookings; 1 Booking tạo ra 1 Contract
CREATE TABLE Bookings (
    BookingID INT PRIMARY KEY IDENTITY(1,1),      -- Mã đặt phòng, khóa chính, tự tăng
    RoomID INT NOT NULL,                          -- Mã phòng, bắt buộc, tham chiếu Rooms
    UserID INT NOT NULL,                          -- Mã người dùng (khách thuê), bắt buộc, tham chiếu Users
    BookingStatus NVARCHAR(30) NOT NULL,          -- Trạng thái đặt phòng: 'Pending' (chờ), 'Approved' (duyệt), 'Rejected' (từ chối), 'Cancelled' (hủy)
    CheckInDate DATETIME NOT NULL,                -- Ngày nhận phòng, bắt buộc
    CheckOutDate DATETIME,                        -- Ngày trả phòng, có thể để trống (để NULL nếu chưa xác định)
    Duration INT,                                 -- Thời gian thuê (tháng), có thể để trống
    DepositAmount DECIMAL(18,2),                  -- Tiền cọc (VND), có thể để trống
    Notes NVARCHAR(MAX),                          -- Ghi chú về đặt phòng (lý do, yêu cầu đặc biệt), có thể để trống
    CreatedAt DATETIME DEFAULT GETDATE(),         -- Ngày tạo đặt phòng, mặc định là thời điểm hiện tại
    UpdatedAt DATETIME DEFAULT GETDATE(),         -- Ngày cập nhật, mặc định là thời điểm hiện tại
    ApprovedBy INT,                               -- Mã Admin phê duyệt, tham chiếu Users, có thể để trống (NULL nếu chưa duyệt)
    ApprovedAt DATETIME,                          -- Ngày phê duyệt, có thể để trống (NULL nếu chưa duyệt)
    CONSTRAINT FK_Bookings_Room FOREIGN KEY (RoomID) REFERENCES Rooms(RoomID), -- FK: RoomID tham chiếu Rooms
    CONSTRAINT FK_Bookings_User FOREIGN KEY (UserID) REFERENCES Users(UserID), -- FK: UserID tham chiếu Users
    CONSTRAINT FK_Bookings_Admin FOREIGN KEY (ApprovedBy) REFERENCES Users(UserID), -- FK: ApprovedBy tham chiếu Users (Admin)
    CONSTRAINT CK_BookingStatus CHECK (BookingStatus IN ('Pending', 'Approved', 'Rejected', 'Cancelled')) -- Ràng buộc: BookingStatus phải là một trong các giá trị
);
GO

-- =====================================================
-- 8. BẢNG CONTRACTS (Hợp đồng)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ hợp đồng thuê phòng chính thức
-- - Tạo tự động: Khi Booking được duyệt (Admin phê duyệt Booking.BookingStatus = 'Approved')
-- - ContractNumber: Mã hợp đồng duy nhất (ví dụ: CT-001-202501)
-- - StartDate/EndDate: Thời gian hiệu lực hợp đồng
-- - RentalPrice: Giá thuê tháng (VND)
-- - DepositAmount: Tiền cọc đã thu
-- - Status: Trạng thái hợp đồng
--   * 'Active' (Hoạt động) - Hợp đồng đang hiệu lực
--   * 'Expired' (Hết hạn) - Hợp đồng đã kết thúc (ngày hiện tại >= EndDate)
--   * 'Terminated' (Chấm dứt) - Hợp đồng bị chấm dứt sớm
-- - ContractTerms: Nội dung, điều khoản hợp đồng (text dài)
-- - SignedDate: Ngày ký kết hợp đồng
-- - Cách hoạt động:
--   1. User tạo Booking
--   2. Admin duyệt Booking → sp_ApproveBooking → tự động gọi sp_CreateContractFromBooking
--   3. Hợp đồng được tạo từ thông tin Booking (StartDate = CheckInDate, EndDate = CheckInDate + Duration tháng)
--   4. Admin tạo hóa đơn từ Contract (Payments)
-- QUAN HỆ: 1 Booking tạo ra 1 Contract; 1 Contract có nhiều Payments (hóa đơn hàng tháng)
CREATE TABLE Contracts (
    ContractID INT PRIMARY KEY IDENTITY(1,1),        -- Mã hợp đồng, khóa chính, tự tăng
    BookingID INT NOT NULL,                          -- Mã đặt phòng, bắt buộc, tham chiếu Bookings (1-to-1)
    ContractNumber NVARCHAR(50) UNIQUE NOT NULL,     -- Số hợp đồng duy nhất (ví dụ: CT-001-202503), bắt buộc
    StartDate DATETIME NOT NULL,                     -- Ngày bắt đầu hợp đồng, bắt buộc
    EndDate DATETIME NOT NULL,                       -- Ngày kết thúc hợp đồng, bắt buộc
    RentalPrice DECIMAL(18,2) NOT NULL,              -- Giá thuê tháng (VND), bắt buộc, phải > 0
    DepositAmount DECIMAL(18,2),                     -- Tiền cọc (VND), có thể để trống
    ContractTerms NVARCHAR(MAX),                     -- Điều khoản hợp đồng (text dài), có thể để trống
    SignedDate DATETIME,                             -- Ngày ký hợp đồng, có thể để trống (NULL nếu chưa ký)
    Status NVARCHAR(30) DEFAULT 'Active',            -- Trạng thái hợp đồng: 'Active' (còn hiệu lực), 'Expired' (hết hạn), 'Terminated' (chấm dứt)
    CreatedAt DATETIME DEFAULT GETDATE(),            -- Ngày tạo hợp đồng, mặc định là thời điểm hiện tại
    UpdatedAt DATETIME DEFAULT GETDATE(),            -- Ngày cập nhật, mặc định là thời điểm hiện tại
    CONSTRAINT FK_Contracts_Booking FOREIGN KEY (BookingID) REFERENCES Bookings(BookingID), -- FK: BookingID tham chiếu Bookings
    CONSTRAINT CK_RentalPrice CHECK (RentalPrice > 0) -- Ràng buộc: Giá thuê phải > 0
);
GO

-- =====================================================
-- 9. BẢNG PAYMENTS (Thanh toán / Hóa đơn)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ hóa đơn/thanh toán của mỗi tháng cho hợp đồng
-- - InvoiceNumber: Mã hóa đơn duy nhất (ví dụ: INV-001-202501)
-- - PaymentDate: Ngày thanh toán được yêu cầu (lưu ngày 1 tháng để dễ truy vấn, ví dụ 2025-02-01)
-- - Amount: Tổng tiền = RentalPrice + Tổng Fees (nước, điện, internet, v.v.)
-- - PaymentStatus: Trạng thái thanh toán
--   * 'Pending' (Chờ thanh toán) - Hóa đơn vừa tạo, chờ user thanh toán
--   * 'Paid' (Đã thanh toán) - User đã thanh toán đủ
--   * 'Overdue' (Quá hạn) - Hết hạn thanh toán nhưng chưa thanh toán
--   * 'Cancelled' (Hủy) - Hóa đơn bị hủy (ví dụ: người thuê chuyển đi, chấm dứt hợp đồng)
-- - PaymentMethod: Cách thanh toán (Tiền mặt, Chuyển khoản, Online, v.v.)
-- - DueDate: Hạn chót thanh toán (thường là ngày 5 hoặc 10 tháng sau)
-- - PaidDate: Ngày thực tế thanh toán (NULL nếu chưa thanh toán)
-- - Cách hoạt động:
--   1. Admin tạo hóa đơn mới từ Contract → Payments.PaymentStatus = 'Pending'
--   2. Hệ thống gửi email thông báo tới User
--   3. User thanh toán → PaymentStatus = 'Paid', PaidDate = ngày thanh toán thực tế
--   4. Nếu quá hạn mà chưa thanh toán → tự động đổi sang 'Overdue'
-- - QUAN HỆ: 1 Contract có nhiều Payments (một cái hóa đơn mỗi tháng); 1 Payment có nhiều Fees
CREATE TABLE Payments (
    PaymentID INT PRIMARY KEY IDENTITY(1,1),             -- Mã thanh toán, khóa chính, tự tăng
    ContractID INT NOT NULL,                             -- Mã hợp đồng, bắt buộc, tham chiếu Contracts
    UserID INT NOT NULL,                                 -- Mã người dùng (người thuê), bắt buộc, tham chiếu Users
    AdminID INT NOT NULL,                                -- Mã Admin quản lý, bắt buộc, tham chiếu Users
    InvoiceNumber NVARCHAR(50) UNIQUE NOT NULL,          -- Số hóa đơn duy nhất (ví dụ: INV-001-202501), bắt buộc
    PaymentDate DATE NOT NULL,                           -- Ngày thanh toán (thường là ngày 1 của tháng), bắt buộc
    Amount DECIMAL(18,2) NOT NULL,                       -- Số tiền (VND), bắt buộc, phải > 0 (tổng = RentalPrice + Fees)
    PaymentStatus NVARCHAR(30) DEFAULT 'Pending',        -- Trạng thái thanh toán: 'Pending' (chưa), 'Paid' (đã), 'Overdue' (quá hạn), 'Cancelled' (hủy)
    PaymentMethod NVARCHAR(50),                          -- Phương thức thanh toán ('Tiền mặt', 'Chuyển khoản', 'Online'), có thể để trống
    DueDate DATETIME,                                    -- Hạn thanh toán, có thể để trống
    PaidDate DATETIME,                                   -- Ngày thực tế thanh toán, có thể để trống (NULL nếu chưa thanh toán)
    Notes NVARCHAR(MAX),                                 -- Ghi chú thanh toán (lý do chậm, lần thanh toán, v.v.), có thể để trống
    CreatedAt DATETIME DEFAULT GETDATE(),                -- Ngày tạo hóa đơn, mặc định là thời điểm hiện tại
    UpdatedAt DATETIME DEFAULT GETDATE(),                -- Ngày cập nhật, mặc định là thời điểm hiện tại
    CONSTRAINT FK_Payments_Contract FOREIGN KEY (ContractID) REFERENCES Contracts(ContractID), -- FK: ContractID tham chiếu Contracts
    CONSTRAINT FK_Payments_User FOREIGN KEY (UserID) REFERENCES Users(UserID), -- FK: UserID tham chiếu Users
    CONSTRAINT FK_Payments_Admin FOREIGN KEY (AdminID) REFERENCES Users(UserID), -- FK: AdminID tham chiếu Users (Admin)
    CONSTRAINT CK_Amount CHECK (Amount > 0), -- Ràng buộc: Số tiền phải > 0
    CONSTRAINT CK_PaymentStatus CHECK (PaymentStatus IN ('Pending', 'Paid', 'Overdue', 'Cancelled')) -- Ràng buộc: PaymentStatus phải là một trong các giá trị
);
GO

-- =====================================================
-- 10. BẢNG FEES (Các khoản phí)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ các khoản phí phụ (nước, điện, internet, gửi xe, v.v.) trong hóa đơn
-- - Mỗi Payment có thể có 0 hoặc nhiều Fees
-- - FeeName: Tên khoản phí (ví dụ: 'Nước', 'Điện', 'Internet', 'Gửi xe', 'Vệ sinh', v.v.)
-- - FeeAmount: Số tiền phí (VND, >= 0)
-- - Description: Ghi chú chi tiết về khoản phí (tùy chọn)
-- - Cách hoạt động:
--   1. Admin tạo hóa đơn mới → nhập giá phòng + nhập thêm các khoản phí
--   2. Hệ thống tính Amount = RentalPrice + SumFees
--   3. Hóa đơn gửi tới User với chi tiết tất cả các khoản phí
--   4. Ví dụ: Tháng 2/2025: Phòng 3,5M + Nước 50K + Điện 150K + Internet 100K = 3,8M
-- - ON DELETE CASCADE: Khi xóa Payment, tất cả Fees của hóa đơn đó cũng bị xóa
-- - LỢI ÍCH: 
--   * Linh hoạt: Admin có thể thêm/xóa khoản phí tùy theo tháng
--   * Dễ quản lý: Thấy rõ ràng từng khoản chi tiết
--   * Báo cáo: Dễ tổng hợp doanh thu theo từng loại phí
-- QUAN HỆ: Nhiều Fees chỉ cùng 1 Payment
CREATE TABLE Fees (
    FeeID INT PRIMARY KEY IDENTITY(1,1),                          -- Mã khoản phí, khóa chính, tự tăng
    PaymentID INT NOT NULL,                                       -- Mã thanh toán, bắt buộc, tham chiếu Payments, xóa tầng (CASCADE)
    FeeName NVARCHAR(100) NOT NULL,                               -- Tên khoản phí ('Nước', 'Điện', 'Internet', 'Gửi xe', 'Vệ sinh'), bắt buộc
    FeeAmount DECIMAL(18,2) NOT NULL,                             -- Số tiền khoản phí (VND), bắt buộc, phải >= 0
    Description NVARCHAR(255),                                    -- Mô tả khoản phí (ví dụ: "5 khối nước"), có thể để trống
    CONSTRAINT FK_Fees_Payment FOREIGN KEY (PaymentID) REFERENCES Payments(PaymentID) ON DELETE CASCADE, -- FK: PaymentID xóa tầng
    CONSTRAINT CK_FeeAmount CHECK (FeeAmount >= 0) -- Ràng buộc: Số tiền phí phải >= 0
);
GO

-- =====================================================
-- 11. BẢNG REVIEWS (Đánh giá và bình luận)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ đánh giá và bình luận của User về phòng
-- - Rating: Mức đánh giá từ 1 đến 5 sao (DECIMAL để hỗ trợ như 4.5)
-- - Comment: Bình luận chi tiết về phòng (text dài, ví dụ: "Phòng đẹp, chủ phòng tử tế, nước nóng tốt")
-- - Status: Trạng thái duyệt bình luận
--   * 'Pending' (Chờ duyệt) - User vừa gửi, chủ phòng chưa duyệt
--   * 'Approved' (Duyệt) - Chủ phòng duyệt, bình luận hiển thị công khai
--   * 'Rejected' (Từ chối) - Chủ phòng từ chối (ví dụ: nội dung spam, lăng mạ)
-- - Cách hoạt động:
--   1. User xem danh sách booking → nếu booking đã duyệt (Approved) → có nút "Đánh giá phòng"
--   2. User gửi đánh giá → Reviews.Status = 'Pending'
--   3. Chủ phòng nhận thông báo, duyệt bình luận
--   4. Admin hoặc chủ phòng xem được tất cả bình luận đã duyệt khi hiển thị chi tiết phòng
-- - LỢI ÍCH: 
--   * Xây dựng uy tín: Hiển thị bình luận từ người thuê thực tế
--   * Tăng conversion: Người tìm kiếm nhìn đánh giá để quyết định
--   * Kiểm soát chất lượng: Admin/chủ phòng duyệt trước khi hiển thị
-- - ON DELETE CASCADE: Khi xóa phòng, tất cả Review của phòng đó cũng bị xóa
-- QUAN HỆ: Nhiều Reviews cho 1 Room; 1 User có thể review nhiều Rooms
CREATE TABLE Reviews (
    ReviewID INT PRIMARY KEY IDENTITY(1,1),            -- Mã đánh giá, khóa chính, tự tăng
    RoomID INT NOT NULL,                               -- Mã phòng, bắt buộc, tham chiếu Rooms, xóa tầng (CASCADE)
    UserID INT NOT NULL,                               -- Mã người dùng (người đánh giá), bắt buộc, tham chiếu Users
    Rating DECIMAL(3,2) NOT NULL,                      -- Điểm đánh giá (1-5 sao, hỗ trợ 4.5), bắt buộc, phải từ 1 đến 5
    Comment NVARCHAR(MAX),                             -- Bình luận chi tiết về phòng, có thể để trống
    Status NVARCHAR(20) DEFAULT 'Approved',            -- Trạng thái duyệt: 'Pending' (chờ duyệt), 'Approved' (đã duyệt), 'Rejected' (từ chối)
    CreatedAt DATETIME DEFAULT GETDATE(),              -- Ngày tạo đánh giá, mặc định là thời điểm hiện tại
    UpdatedAt DATETIME DEFAULT GETDATE(),              -- Ngày cập nhật, mặc định là thời điểm hiện tại
    CONSTRAINT FK_Reviews_Room FOREIGN KEY (RoomID) REFERENCES Rooms(RoomID) ON DELETE CASCADE, -- FK: RoomID xóa tầng
    CONSTRAINT FK_Reviews_User FOREIGN KEY (UserID) REFERENCES Users(UserID), -- FK: UserID tham chiếu Users
    CONSTRAINT CK_Rating CHECK (Rating >= 1 AND Rating <= 5) -- Ràng buộc: Rating phải từ 1 đến 5
);
GO

-- =====================================================
-- 12. BẢNG NOTIFICATIONS (Thông báo)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ tất cả thông báo gửi tới User
-- - RecipientID: ID người nhận thông báo (User)
-- - SenderID: ID người gửi (Admin hoặc NULL nếu từ hệ thống)
-- - Title: Tiêu đề thông báo (ví dụ: "Đặt phòng được phê duyệt")
-- - Message: Nội dung chi tiết của thông báo
-- - Type: Loại thông báo (để lọc và hiển thị biểu tượng khác nhau)
--   * 'Booking' - Liên quan tới đặt phòng (mới, duyệt, từ chối, hủy)
--   * 'Payment' - Liên quan tới thanh toán/hóa đơn (mới, quá hạn, nhắc nhở)
--   * 'Maintenance' - Liên quan tới bảo trì phòng
--   * 'System' - Thông báo hệ thống (cập nhật, bảo trì)
--   * 'Contract' - Liên quan tới hợp đồng (chấm dứt, gia hạn, v.v.)
-- - RelatedEntityType/RelatedEntityID: Để theo dõi thông báo liên quan tới đối tượng nào (Room, Booking, Payment, Contract)
-- - IsRead: BIT để đánh dấu thông báo đã đọc hay chưa (User nhấn vào thông báo → IsRead = 1)
-- - ReadAt: Thời gian User đọc thông báo
-- - Cách hoạt động: Tự động được gọi từ các stored procedure khi:
--   1. Booking được tạo → gửi thông báo tới Admin
--   2. Booking được duyệt → gửi thông báo tới User
--   3. Hóa đơn được tạo → gửi thông báo tới User
--   4. Hóa đơn sắp quá hạn → gửi nhắc nhở
-- - LỢI ÍCH: Người dùng luôn cập nhật các sự kiện quan trọng mà không cần check email
-- QUAN HỆ: 1 User (RecipientID) có nhiều Notifications; 1 User (SenderID) có thể gửi nhiều Notifications
CREATE TABLE Notifications (
    NotificationID INT PRIMARY KEY IDENTITY(1,1),    -- Mã thông báo, khóa chính, tự tăng
    RecipientID INT NOT NULL,                        -- Mã người nhận thông báo (User), bắt buộc, tham chiếu Users
    SenderID INT,                                    -- Mã người gửi (Admin hoặc NULL nếu từ hệ thống), tham chiếu Users
    Title NVARCHAR(200) NOT NULL,                    -- Tiêu đề thông báo (ví dụ: "Đặt phòng được phê duyệt"), bắt buộc
    Message NVARCHAR(MAX),                           -- Nội dung chi tiết thông báo, có thể để trống
    Type NVARCHAR(50),                               -- Loại thông báo: 'Booking', 'Payment', 'Maintenance', 'System', 'Contract', có thể để trống
    RelatedEntityType NVARCHAR(50),                  -- Loại thực thể liên quan: 'Room', 'Booking', 'Payment', 'Contract', có thể để trống
    RelatedEntityID INT,                             -- ID của thực thể liên quan (ví dụ: BookingID, PaymentID), có thể để trống
    IsRead BIT DEFAULT 0,                            -- Trạng thái đã đọc (1=đã, 0=chưa), mặc định 0
    CreatedAt DATETIME DEFAULT GETDATE(),            -- Ngày tạo thông báo, mặc định là thời điểm hiện tại
    ReadAt DATETIME,                                 -- Ngày đọc thông báo, có thể để trống (NULL nếu chưa đọc)
    CONSTRAINT FK_Notifications_Recipient FOREIGN KEY (RecipientID) REFERENCES Users(UserID), -- FK: RecipientID tham chiếu Users
    CONSTRAINT FK_Notifications_Sender FOREIGN KEY (SenderID) REFERENCES Users(UserID) -- FK: SenderID tham chiếu Users
);
GO

-- =====================================================
-- 13. BẢNG ACTIVITY_LOGS (Lịch sử hoạt động)
-- =====================================================
-- CHỨC NĂNG: Ghi lại tất cả hoạt động quan trọng trong hệ thống để kiểm toán (audit trail)
-- - Giúp: Theo dõi ai đã làm gì, khi nào, và nội dung thay đổi là gì
-- - ActionType: Loại hành động
--   * 'CREATE' - Tạo mới (Room, Booking, User)
--   * 'UPDATE' - Chỉnh sửa (thay đổi thông tin)
--   * 'DELETE' - Xóa
--   * 'LOGIN' - Đăng nhập
--   * 'APPROVE' - Phê duyệt (Booking, Review)
--   * 'REJECT' - Từ chối
--   * 'CANCEL' - Hủy
--   * 'LOCK' - Khóa tài khoản
-- - EntityType: Loại đối tượng bị thay đổi (Room, Booking, User, Payment, v.v.)
-- - EntityID: ID của đối tượng đó (ví dụ RoomID=1 nếu là Room)
-- - OldValues/NewValues: Giá trị cũ và giá trị mới (lưu dưới dạng JSON để dễ so sánh)
--   * Ví dụ OldValues: {"Price": 3500000, "Status": "Available"}
--   * Ví dụ NewValues: {"Price": 3600000, "Status": "Rented"}
-- - IPAddress: Địa chỉ IP của người tạo hành động (để phát hiện hoạt động bất thường)
-- - Description: Mô tả chi tiết về hành động (ví dụ: "Admin Nguyễn Văn A tạo phòng mới A101")
-- - CreatedAt: Thời gian hành động xảy ra
-- - Cách hoạt động:
--   * Tự động ghi log khi stored procedure thực hiện:
--     - sp_AddRoom, sp_UpdateRoom, sp_UpdateRoomStatus
--     - sp_CreateBooking, sp_CancelBooking, sp_ApproveBooking, sp_RejectBooking
--     - sp_CreateInvoice
--     - sp_Login (đăng nhập)
--     - sp_LockUnlockUser
--   * Có thể truy vấn để tạo báo cáo: "Ai thay đổi giá phòng lần cuối?", "Booking nào bị từ chối?"
-- - LỢI ÍCH:
--   * Audit: Giám sát hoạt động của Admin
--   * Debugging: Tìm ra lỗi hoặc ai đã xóa dữ liệu
--   * Compliance: Tuân thủ yêu cầu ghi log
-- QUAN HỆ: 1 User (UserID) có nhiều ActivityLogs
CREATE TABLE ActivityLogs (
    LogID INT PRIMARY KEY IDENTITY(1,1),           -- Mã nhật ký, khóa chính, tự tăng
    UserID INT,                                    -- Mã người dùng thực hiện hành động, tham chiếu Users, có thể để trống (NULL nếu từ hệ thống)
    ActionType NVARCHAR(100) NOT NULL,             -- Loại hành động: 'CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'APPROVE', 'REJECT', 'CANCEL', 'LOCK', v.v., bắt buộc
    EntityType NVARCHAR(50),                       -- Loại thực thể tác động: 'Room', 'Booking', 'User', 'Payment', 'Contract', 'Review', có thể để trống
    EntityID INT,                                  -- ID của thực thể (ví dụ: RoomID, BookingID), có thể để trống
    OldValues NVARCHAR(MAX),                       -- Giá trị cũ (định dạng JSON để lưu trữ dữ liệu cũ), có thể để trống
    NewValues NVARCHAR(MAX),                       -- Giá trị mới (định dạng JSON để lưu trữ dữ liệu mới), có thể để trống
    IPAddress NVARCHAR(45),                        -- Địa chỉ IP của người thực hiện (IPv4 hoặc IPv6), có thể để trống
    Description NVARCHAR(MAX),                     -- Mô tả chi tiết hành động, có thể để trống
    CreatedAt DATETIME DEFAULT GETDATE(),          -- Ngày tạo bản ghi, mặc định là thời điểm hiện tại
    CONSTRAINT FK_ActivityLogs_User FOREIGN KEY (UserID) REFERENCES Users(UserID) -- FK: UserID tham chiếu Users
);
GO

-- =====================================================
-- 14. BẢNG SYSTEM_SETTINGS (Cài đặt hệ thống)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ các cài đặt cấu hình của hệ thống dạng key-value
-- - Admin có thể thay đổi các cài đặt này mà không cần sửa code
-- - Các cài đặt thường gặp:
--   * EMAIL_SMTP_SERVER: Server gửi email (ví dụ: smtp.gmail.com)
--   * EMAIL_SMTP_PORT: Port (ví dụ: 587)
--   * EMAIL_FROM_ADDRESS: Email gửi thông báo (ví dụ: noreply@rentingapp.com)
--   * EMAIL_PASSWORD: Mật khẩu email
--   * SYSTEM_NAME: Tên hệ thống hiển thị (ví dụ: "Hệ thống Thuê Phòng Trọ")
--   * SYSTEM_URL: URL của trang web (ví dụ: https://rentingapp.com)
--   * MAX_UPLOAD_SIZE: Kích thước file upload tối đa (ví dụ: 5242880 bytes = 5MB)
--   * ALLOWED_IMAGE_TYPES: Các loại file ảnh cho phép (ví dụ: "jpg,jpeg,png,gif")
--   * PASSWORD_RESET_EXPIRY: Hết hạn token reset mật khẩu (ví dụ: 86400 giây = 24 giờ)
--   * EMAIL_VERIFICATION_EXPIRY: Hết hạn token xác thực email (ví dụ: 86400 giây = 24 giờ)
--   * PAYMENT_REMINDER_DAYS_BEFORE: Nhắc nhở thanh toán trước bao nhiêu ngày (ví dụ: 3)
--   * PAYMENT_OVERDUE_DAYS: Khi nào coi là quá hạn (ví dụ: 5 ngày)
-- - Cách hoạt động:
--   1. Application khởi động → đọc tất cả settings từ bảng này vào bộ nhớ
--   2. Admin vào menu "Cài đặt" → thay đổi giá trị → Update bảng
--   3. Application tải lại cài đặt hoặc sử dụng cache
-- - LỢI ÍCH: Linh hoạt, không cần deploy lại khi thay đổi cài đặt
-- QUAN HỆ: Bảng độc lập, không tham chiếu bảng khác
CREATE TABLE SystemSettings (
    SettingID INT PRIMARY KEY IDENTITY(1,1),             -- Mã cài đặt, khóa chính, tự tăng
    SettingKey NVARCHAR(100) UNIQUE NOT NULL,            -- Khóa cài đặt (ví dụ: 'EMAIL_SMTP_SERVER', 'SYSTEM_NAME'), duy nhất, bắt buộc
    SettingValue NVARCHAR(MAX),                          -- Giá trị cài đặt (ví dụ: 'smtp.gmail.com', 'Hệ thống Thuê Phòng'), có thể để trống
    Description NVARCHAR(255),                           -- Mô tả cài đặt (ví dụ: 'Server SMTP để gửi email'), có thể để trống
    UpdatedAt DATETIME DEFAULT GETDATE()                 -- Ngày cập nhật, mặc định là thời điểm hiện tại
);
GO

-- =====================================================
-- 15. BẢNG PASSWORD_RESET_TOKENS (Token khôi phục mật khẩu)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ token tạm thời để người dùng quên mật khẩu có thể reset
-- - Token: Chuỗi ngẫu nhiên duy nhất (ví dụ: "abc123xyz789...")
-- - ExpiresAt: Thời gian token hết hạn (thường 24 giờ sau khi tạo)
-- - IsUsed: BIT để đánh dấu token đã được sử dụng hay chưa (bảo vệ chống sử dụng lại)
-- - Cách hoạt động:
--   1. User nhấn "Quên mật khẩu" → nhập email
--   2. Hệ thống gọi sp_CreatePasswordResetToken → tạo token, gửi email với link
--   3. Email chứa link: https://website.com/reset-password?token=abc123xyz789
--   4. User nhấn link → gửi token tới server
--   5. Server kiểm tra: Token tồn tại? Chưa hết hạn? Chưa được dùng?
--   6. Nếu hợp lệ → cho phép User nhập mật khẩu mới
--   7. Mật khẩu cập nhật → token.IsUsed = 1 (không thể dùng lại)
-- - Bảo mật:
--   * Token hết hạn nếu User không xử lý trong 24 giờ
--   * 1 token chỉ dùng được 1 lần (IsUsed = 1 sau khi reset)
--   * Nếu User forgot lần 2 → phải tạo token mới
-- - ON DELETE CASCADE: Khi xóa User, tất cả token reset của User đó cũng bị xóa
-- QUAN HỆ: 1 User có thể có nhiều PasswordResetTokens (từng lần quên mật khẩu)
CREATE TABLE PasswordResetTokens (
    TokenID INT PRIMARY KEY IDENTITY(1,1),                -- Mã token, khóa chính, tự tăng
    UserID INT NOT NULL,                                  -- Mã người dùng (người yêu cầu reset), bắt buộc, tham chiếu Users, xóa tầng (CASCADE)
    Token NVARCHAR(255) UNIQUE NOT NULL,                  -- Token duy nhất ngẫu nhiên (ví dụ: chuỗi 32-64 ký tự), duy nhất, bắt buộc
    ExpiresAt DATETIME NOT NULL,                          -- Thời gian token hết hạn (thường 24 giờ sau khi tạo), bắt buộc
    IsUsed BIT DEFAULT 0,                                 -- Trạng thái đã sử dụng (1=đã, 0=chưa), mặc định 0 (bảo vệ chống sử dụng lại)
    CreatedAt DATETIME DEFAULT GETDATE(),                 -- Ngày tạo token, mặc định là thời điểm hiện tại
    CONSTRAINT FK_PasswordReset_User FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE -- FK: UserID xóa tầng
);
GO

-- =====================================================
-- 16. BẢNG EMAIL_VERIFICATION_TOKENS (Token xác thực Email)
-- =====================================================
-- CHỨC NĂNG: Lưu trữ token tạm thời để xác thực email của người dùng mới
-- - Token: Chuỗi ngẫu nhiên duy nhất (ví dụ: "verify123abc...")
-- - ExpiresAt: Thời gian token hết hạn (thường 24 giờ sau khi tạo)
-- - IsUsed: BIT để đánh dấu token đã được sử dụng hay chưa (User đã xác thực email)
-- - Cách hoạt động:
--   1. User nhấn "Đăng ký" → nhập email, mật khẩu
--   2. Hệ thống gọi sp_RegisterUser → tạo User, gọi sp_CreateEmailVerificationToken
--   3. Tạo token, gửi email với link xác thực: https://website.com/verify-email?token=verify123abc
--   4. User mở email → nhấn link
--   5. Server kiểm tra: Token tồn tại? Chưa hết hạn? Chưa được dùng?
--   6. Nếu hợp lệ → cập nhật Users.IsEmailVerified = 1, token.IsUsed = 1
--   7. User được phép đăng nhập (vì IsEmailVerified = 1)
-- - Bảo mật:
--   * Email phải xác thực mới có thể sử dụng hệ thống (ngăn chặn email spam/giả)
--   * Token hết hạn nếu User không xử lý trong 24 giờ → phải tạo tài khoản lại
--   * 1 token chỉ dùng được 1 lần
-- - ON DELETE CASCADE: Khi xóa User, tất cả token xác thực email của User đó cũng bị xóa
-- QUAN HỆ: 1 User có thể có nhiều EmailVerificationTokens (nếu token hết hạn, phải tạo lại)
CREATE TABLE EmailVerificationTokens (
    TokenID INT PRIMARY KEY IDENTITY(1,1),                -- Mã token, khóa chính, tự tăng
    UserID INT NOT NULL,                                  -- Mã người dùng (người đăng ký), bắt buộc, tham chiếu Users, xóa tầng (CASCADE)
    Token NVARCHAR(255) UNIQUE NOT NULL,                  -- Token duy nhất ngẫu nhiên để xác thực email, duy nhất, bắt buộc
    ExpiresAt DATETIME NOT NULL,                          -- Thời gian token hết hạn (thường 24 giờ sau khi đăng ký), bắt buộc
    IsUsed BIT DEFAULT 0,                                 -- Trạng thái đã sử dụng (1=đã xác thực, 0=chưa), mặc định 0 (bảo vệ chống sử dụng lại)
    CreatedAt DATETIME DEFAULT GETDATE(),                 -- Ngày tạo token, mặc định là thời điểm hiện tại
    CONSTRAINT FK_EmailVerification_User FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE -- FK: UserID xóa tầng
);
GO

-- =====================================================
-- THÊM DỮ LIỆU KHỞI TẠO BAN ĐẦU
-- =====================================================

-- Thêm trạng thái phòng
INSERT INTO RoomStatuses (StatusName, Description) VALUES
('Available', N'Phòng đang trống, sẵn sàng cho thuê'),
('Rented', N'Phòng đang được thuê'),
('Maintenance', N'Phòng đang bảo trì'),
('Reserved', N'Phòng đã được đặt, chờ xác nhận');

-- Thêm tiện ích mặc định
INSERT INTO Utilities (UtilityName, Description) VALUES
('WiFi', N'Internet không dây'),
(N'Điều hòa', N'Máy điều hòa nhiệt độ'),
(N'Tủ lạnh', N'Tủ lạnh'),
(N'Giường', N'Giường tiêu chuẩn'),
(N'Bàn làm việc', N'Bàn làm việc'),
(N'Phòng tắm riêng', N'Phòng tắm riêng cho thuê bao'),
(N'Bếp nấu', N'Bếp để nấu ăn'),
(N'Giặt tự động', N'Máy giặt tự động'),
('TV', N'Tivi'),
(N'Bảo mật 24/7', N'Camera giám sát 24/7');

-- =====================================================
-- THÊM DỮ LIỆU CHI TIẾT
-- =====================================================

-- Thêm các địa chỉ (40 dòng - mở rộng để tránh lặp)
INSERT INTO Addresses (Street, Ward, District, City, Province, ZipCode, Latitude, Longitude) VALUES
(N'07 Đoàn Trần Nghiệp', N'Vĩnh Phước', N'Nha Trang', N'Khánh Hòa', N'Khánh Hòa', '65000', 12.2681, 109.1989),
(N'123 Nguyễn Huệ', N'Bến Nghé', N'Quận 1', N'TP.HCM', N'TP.HCM', '70000', 10.7749, 106.7015),
(N'456 Đinh Bộ Lĩnh', N'Bến Thành', N'Quận 1', N'TP.HCM', N'TP.HCM', '70001', 10.7722, 106.6976),
(N'789 Lê Lợi', N'Nguyễn Hữu Cảnh', N'Quận 1', N'TP.HCM', N'TP.HCM', '70002', 10.7780, 106.7050),
(N'321 Trần Hưng Đạo', N'Tân Định', N'Quận 1', N'TP.HCM', N'TP.HCM', '70003', 10.7700, 106.7100),
(N'654 Nguyễn Thái Bình', N'Tây Thạnh', N'Quận Tân Phú', N'TP.HCM', N'TP.HCM', '70200', 10.8050, 106.6200),
(N'987 Phan Văn Trị', N'Tân Bình', N'Quận Tân Bình', N'TP.HCM', N'TP.HCM', '70300', 10.8200, 106.6450),
(N'147 Cách Mạng Tháng 8', N'Phường 8', N'Quận 3', N'TP.HCM', N'TP.HCM', '70100', 10.7950, 106.6850),
(N'258 Cao Thắng', N'Phường 2', N'Quận 3', N'TP.HCM', N'TP.HCM', '70101', 10.8000, 106.6900),
(N'369 Võ Văn Tần', N'Phường 6', N'Quận 3', N'TP.HCM', N'TP.HCM', '70102', 10.8100, 106.7000),
(N'741 Lê Thánh Tôn', N'Bến Nghé', N'Quận 1', N'TP.HCM', N'TP.HCM', '70004', 10.7690, 106.7030),
-- Thêm 30 địa chỉ mới
(N'234 Hai Bà Trưng', N'Tân Định', N'Quận 1', N'TP.HCM', N'TP.HCM', '70005', 10.7800, 106.7020),
(N'567 Pasteur', N'Phường 6', N'Quận 3', N'TP.HCM', N'TP.HCM', '70103', 10.7820, 106.6950),
(N'891 Nguyễn Đình Chiểu', N'Đa Kao', N'Quận 1', N'TP.HCM', N'TP.HCM', '70006', 10.7850, 106.7080),
(N'345 Lý Tự Trọng', N'Bến Thành', N'Quận 1', N'TP.HCM', N'TP.HCM', '70007', 10.7730, 106.6980),
(N'678 Nam Kỳ Khởi Nghĩa', N'Nguyễn Thái Bình', N'Quận 1', N'TP.HCM', N'TP.HCM', '70008', 10.7760, 106.7010),
(N'912 Tôn Đức Thắng', N'Bến Nghé', N'Quận 1', N'TP.HCM', N'TP.HCM', '70009', 10.7720, 106.7040),
(N'456 Nguyễn Trãi', N'Phường 7', N'Quận 5', N'TP.HCM', N'TP.HCM', '70500', 10.7550, 106.6750),
(N'789 Trần Phú', N'Phường 4', N'Quận 5', N'TP.HCM', N'TP.HCM', '70501', 10.7580, 106.6720),
(N'123 Hùng Vương', N'Phường 1', N'Quận 5', N'TP.HCM', N'TP.HCM', '70502', 10.7600, 106.6700),
(N'234 An Dương Vương', N'Phường 9', N'Quận 5', N'TP.HCM', N'TP.HCM', '70503', 10.7620, 106.6680),
(N'567 Điện Biên Phủ', N'Đa Kao', N'Quận 1', N'TP.HCM', N'TP.HCM', '70010', 10.7880, 106.7100),
(N'891 Hoàng Sa', N'Đa Kao', N'Quận 1', N'TP.HCM', N'TP.HCM', '70011', 10.7900, 106.7120),
(N'345 Trường Sa', N'Phường 21', N'Bình Thạnh', N'TP.HCM', N'TP.HCM', '71000', 10.8050, 106.7150),
(N'678 Xô Viết Nghệ Tĩnh', N'Phường 25', N'Bình Thạnh', N'TP.HCM', N'TP.HCM', '71001', 10.8100, 106.7180),
(N'912 Bạch Đằng', N'Phường 24', N'Bình Thạnh', N'TP.HCM', N'TP.HCM', '71002', 10.8120, 106.7200),
(N'234 Phan Đăng Lưu', N'Phường 5', N'Phú Nhuận', N'TP.HCM', N'TP.HCM', '72000', 10.7980, 106.6820),
(N'567 Huỳnh Văn Bánh', N'Phường 11', N'Phú Nhuận', N'TP.HCM', N'TP.HCM', '72001', 10.8000, 106.6850),
(N'891 Trần Huy Liệu', N'Phường 12', N'Phú Nhuận', N'TP.HCM', N'TP.HCM', '72002', 10.8020, 106.6880),
(N'345 Nguyễn Văn Trỗi', N'Phường 1', N'Tân Bình', N'TP.HCM', N'TP.HCM', '70301', 10.8250, 106.6500),
(N'678 Hoàng Văn Thụ', N'Phường 4', N'Tân Bình', N'TP.HCM', N'TP.HCM', '70302', 10.8270, 106.6520),
(N'912 Trường Chinh', N'Phường 12', N'Tân Bình', N'TP.HCM', N'TP.HCM', '70303', 10.8300, 106.6550),
(N'234 Lạc Long Quân', N'Phường 5', N'Quận 11', N'TP.HCM', N'TP.HCM', '71100', 10.7650, 106.6500),
(N'567 Lý Thường Kiệt', N'Phường 7', N'Quận 11', N'TP.HCM', N'TP.HCM', '71101', 10.7680, 106.6520),
(N'891 Đại lộ Hòa Bình', N'Phường 3', N'Quận 11', N'TP.HCM', N'TP.HCM', '71102', 10.7700, 106.6540),
(N'345 Võ Thị Sáu', N'Phường 7', N'Quận 3', N'TP.HCM', N'TP.HCM', '70104', 10.7920, 106.6920),
(N'678 Nguyễn Thị Minh Khai', N'Phường 5', N'Quận 3', N'TP.HCM', N'TP.HCM', '70105', 10.7940, 106.6940),
(N'912 Lê Văn Sỹ', N'Phường 14', N'Quận 3', N'TP.HCM', N'TP.HCM', '70106', 10.7960, 106.6960),
(N'234 Phạm Ngọc Thạch', N'Phường 6', N'Quận 3', N'TP.HCM', N'TP.HCM', '70107', 10.7870, 106.6930),
(N'567 Nguyễn Văn Cừ', N'Phường 1', N'Quận 5', N'TP.HCM', N'TP.HCM', '70504', 10.7640, 106.6660),
(N'891 Hải Thượng Lãn Ông', N'Phường 10', N'Quận 5', N'TP.HCM', N'TP.HCM', '70505', 10.7560, 106.6640);

-- Thêm người dùng (5 Admin + Nhiều User)
INSERT INTO Users (Username, Email, PasswordHash, FirstName, LastName, PhoneNumber, Role, AddressID, IsActive, IsEmailVerified, CreatedAt) VALUES
-- Admin (quản lý) - Tạo 5 Admin để phân bổ quản lý phòng
('admin', 'admin@rentingapp.com', 'admin@rentingapp.com', N'Nguyễn', N'Văn A', '0901234567', 0, 1, 1, 1, '2024-01-01'),
('admin_tran', 'admin.tran@rentingapp.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Trần', N'Văn B', '0901234568', 0, 11, 1, 1, '2024-01-01'),
('admin_le', 'admin.le@rentingapp.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Lê', N'Thị C', '0901234569', 0, 12, 1, 1, '2024-01-01'),
('admin_pham', 'admin.pham@rentingapp.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Phạm', N'Văn D', '0901234570', 0, 13, 1, 1, '2024-01-01'),
('admin_hoang', 'admin.hoang@rentingapp.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Hoàng', N'Thị E', '0901234571', 0, 14, 1, 1, '2024-01-01'),
-- User (người thuê) - Sử dụng địa chỉ không lặp lại
('user_thanh', 'thanh.nguyen@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Thanh', N'Nguyễn', '0906789012', 1, 15, 1, 1, '2024-02-01'),
('user_linh', 'linh.tran@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Linh', N'Trần', '0907890123', 1, 16, 1, 1, '2024-02-05'),
('user_hoa', 'hoa.le@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Hoa', N'Lê', '0908901234', 1, 17, 1, 1, '2024-02-10'),
('user_minh', 'minh.pham@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Minh', N'Phạm', '0909012345', 1, 18, 1, 1, '2024-02-15'),
('user_tuan', 'tuan.hoang@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Tuấn', N'Hoàng', '0910123456', 1, 19, 1, 1, '2024-02-20'),
('user_huong', 'huong.pham@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Hương', N'Phạm', '0911234567', 1, 20, 1, 1, '2024-02-25'),
('user_dung', 'dung.nguyen@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Dũng', N'Nguyễn', '0912345678', 1, 21, 1, 1, '2024-03-01'),
('user_lan', 'lan.tran@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Lan', N'Trần', '0913456789', 1, 22, 1, 1, '2024-03-05'),
('user_hung', 'hung.nguyen@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Hùng', N'Nguyễn', '0914567890', 1, 23, 1, 1, '2024-03-10'),
('user_mai', 'mai.le@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Mai', N'Lê', '0915678901', 1, 24, 1, 1, '2024-03-12'),
('user_khanh', 'khanh.pham@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Khánh', N'Phạm', '0916789012', 1, 25, 1, 1, '2024-03-15'),
('user_thy', 'thy.hoang@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Thủy', N'Hoàng', '0917890123', 1, 26, 1, 1, '2024-03-18'),
('user_nhan', 'nhan.tran@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Nhân', N'Trần', '0918901234', 1, 27, 1, 1, '2024-03-20'),
('user_phuong', 'phuong.nguyen@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Phương', N'Nguyễn', '0919012345', 1, 28, 1, 1, '2024-03-22'),
('user_duc', 'duc.le@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Đức', N'Lê', '0920123456', 1, 29, 1, 1, '2024-03-25'),
('user_linh_2', 'linh2.pham@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Linh', N'Phạm', '0921234567', 1, 30, 1, 1, '2024-03-28'),
('user_khoa', 'khoa.hoang@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Khoa', N'Hoàng', '0922345678', 1, 31, 1, 1, '2024-03-30'),
('user_tram', 'tram.nguyen@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Trâm', N'Nguyễn', '0923456789', 1, 32, 1, 1, '2024-04-01'),
('user_dung_2', 'dung2.tran@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Dũng', N'Trần', '0924567890', 1, 33, 1, 1, '2024-04-03'),
('user_thanh_2', 'thanh2.le@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Thành', N'Lê', '0925678901', 1, 34, 1, 1, '2024-04-05'),
('user_hanh', 'hanh.pham@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Hạnh', N'Phạm', '0926789012', 1, 35, 1, 1, '2024-04-07'),
('user_tien', 'tien.hoang@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Tiến', N'Hoàng', '0927890123', 1, 36, 1, 1, '2024-04-09'),
('user_huyen', 'huyen.tran@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Huyền', N'Trần', '0928901234', 1, 37, 1, 1, '2024-04-11'),
('user_minh_2', 'minh2.nguyen@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Minh', N'Nguyễn', '0929012345', 1, 38, 1, 1, '2024-04-13'),
('user_quynh', 'quynh.le@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Quỳnh', N'Lê', '0930123456', 1, 39, 1, 1, '2024-04-15'),
('user_tung', 'tung.pham@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Tùng', N'Phạm', '0931234567', 1, 40, 1, 1, '2024-04-17'),
('user_tam', 'tam.hoang@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Tâm', N'Hoàng', '0932345678', 1, 2, 1, 1, '2024-04-19'),
('user_nam', 'nam.tran@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Nam', N'Trần', '0933456789', 1, 3, 1, 1, '2024-04-21'),
('user_vy', 'vy.nguyen@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Vy', N'Nguyễn', '0934567890', 1, 4, 1, 1, '2024-04-23'),
('user_tao', 'tao.le@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Táo', N'Lê', '0935678901', 1, 5, 1, 1, '2024-04-25'),
('user_ha', 'ha.pham@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Hà', N'Phạm', '0936789012', 1, 6, 1, 1, '2024-04-27'),
('user_binh', 'binh.hoang@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Bình', N'Hoàng', '0937890123', 1, 7, 1, 1, '2024-04-29'),
('user_an', 'an.tran@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'An', N'Trần', '0938901234', 1, 8, 1, 1, '2024-05-01'),
('user_thu', 'thu.nguyen@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Thu', N'Nguyễn', '0939012345', 1, 9, 1, 1, '2024-05-03'),
('user_son', 'son.le@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Sơn', N'Lê', '0940123456', 1, 10, 1, 1, '2024-05-05'),
('user_hang', 'hang.pham@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Hằng', N'Phạm', '0941234567', 1, 1, 1, 1, '2024-05-07'),
('user_duong', 'duong.hoang@email.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36CHqV36', N'Dương', N'Hoàng', '0942345678', 1, 2, 1, 1, '2024-05-09'),
('user', 'user@email.com', 'user@email.com', N'User', N'Test', '0942345678', 1, 2, 1, 1, '2024-05-09');



-- Thêm phòng trọ (10 dòng)
INSERT INTO Rooms (RoomNumber, AdminID, Title, Description, Area, Price, AddressID, MaxOccupancy, StatusID, CreatedAt) VALUES
('A101', 1, N'Phòng đẹp gần trường', N'Phòng rộng 25m², thoáng mát, gần trường', 25.5, 3500000, 1, 2, 1, '2024-01-15'),
('A102', 1, N'Phòng yên tĩnh', N'Phòng yên tĩnh, có cửa sổ, đón nắng', 20.0, 3000000, 1, 1, 1, '2024-01-15'),
('B201', 2, N'Phòng hiện đại', N'Phòng mới, nội thất đầy đủ, có bếp', 30.0, 4500000, 5, 3, 1, '2024-01-20'),
('B202', 2, N'Phòng nhỏ gọn', N'Phòng nhỏ nhưng đầy đủ tiện nghi', 18.0, 2500000, 5, 1, 1, '2024-01-20'),
('C301', 3, N'Phòng view đẹp', N'Phòng view sông, thoáng, đẹp', 35.0, 5500000, 6, 4, 1, '2024-01-25'),
('C302', 3, N'Phòng bình dân', N'Phòng giá rẻ, đơn giản nhưng sạch sẽ', 15.0, 2000000, 6, 1, 1, '2024-01-25'),
('D401', 4, N'Phòng cao cấp', N'Phòng sang trọng, full tiện ích', 50.0, 8000000, 7, 5, 1, '2024-02-01'),
('D402', 4, N'Phòng tiêu chuẩn', N'Phòng tiêu chuẩn, địa điểm tốt', 25.0, 3800000, 7, 2, 1, '2024-02-01'),
('E501', 5, N'Phòng gia đình', N'Phòng rộng, thích hợp cho gia đình', 45.0, 6500000, 8, 6, 1, '2024-02-05'),
('E502', 5, N'Phòng sinh viên', N'Phòng giá học sinh, gần đại học', 22.0, 2800000, 8, 2, 1, '2024-02-05'),
('F601', 1, N'Phòng gần bến xe', N'Gần bến xe, tiện giao thông, có A/C', 26.0, 3400000, 9, 2, 1, '2024-02-10'),
('F602', 1, N'Phòng cozy', N'Phòng nhỏ cozy, chủ phòng tử tế', 17.0, 2200000, 9, 1, 1, '2024-02-10'),
('G701', 2, N'Phòng đầy đủ tiện ích', N'Có bếp, máy giặt, Internet nhanh', 28.0, 3900000, 2, 3, 1, '2024-02-15'),
('G702', 2, N'Phòng rộng thoáng', N'Rộng, thoáng, đủ nắng chiều', 32.0, 4200000, 2, 3, 1, '2024-02-15'),
('H801', 3, N'Phòng yên tĩnh gần công viên', N'Yên tĩnh, gần công viên 23/9, view xanh', 29.0, 4000000, 3, 2, 1, '2024-02-20'),
('H802', 3, N'Phòng ký túc xá', N'Giá rẻ, phù hợp sinh viên', 16.0, 1800000, 3, 1, 1, '2024-02-20'),
('I901', 4, N'Phòng sang', N'Nội thất cao cấp, nước nóng 24/7', 48.0, 7500000, 4, 5, 3, '2024-02-25'),
('I902', 4, N'Phòng tiện ích', N'Đầy đủ tiện ích, quản lý tốt', 24.0, 3600000, 4, 2, 1, '2024-02-25'),
('J1001', 5, N'Phòng dạo phố', N'Gần trung tâm, tiện đi chơi', 21.0, 3300000, 10, 2, 1, '2024-03-01'),
('J1002', 5, N'Phòng bình yên', N'Bình yên, đơn giản nhưng đầy đủ', 19.0, 2600000, 10, 1, 2, '2024-03-01'),
('K1101', 1, N'Phòng mới toanh', N'Vừa sửa xong, như mới', 27.0, 3700000, 1, 2, 1, '2024-03-05'),
('K1102', 1, N'Phòng ổn định', N'Cho thuê lâu dài, giá ổn định', 23.0, 3100000, 1, 2, 1, '2024-03-05'),
('L1201', 2, N'Phòng duplex', N'Duplex, 2 tầng, thoáng mát', 40.0, 5800000, 5, 4, 1, '2024-03-10'),
('L1202', 2, N'Phòng nhỏ xinh', N'Nhỏ nhưng được trang trí xinh xắn', 18.0, 2400000, 5, 1, 1, '2024-03-10'),
('M1301', 3, N'Phòng view đường phố', N'View đường phố, đèn sáng về đêm', 31.0, 4300000, 6, 3, 1, '2024-03-15'),
('M1302', 3, N'Phòng bến cạnh', N'Bến cạnh, gần chợ, tiện mua bán', 20.0, 2700000, 6, 1, 1, '2024-03-15'),
('N1401', 4, N'Phòng luxury', N'Luxury, đầy đủ tất cả', 55.0, 8500000, 7, 6, 2, '2024-03-20'),
('N1402', 4, N'Phòng standard', N'Standard, đủ dùng', 25.0, 3500000, 7, 2, 1, '2024-03-20'),
('O1501', 5, N'Phòng gia đình rộng', N'Rộng, phù hợp gia đình 5-6 người', 42.0, 6200000, 8, 6, 1, '2024-03-25'),
('O1502', 5, N'Phòng cô đơn nhân viên', N'Phù hợp nhân viên sống một mình', 15.0, 2000000, 8, 1, 1, '2024-03-25'),
('P1601', 1, N'Phòng near station', N'Gần trạm xe, tiện di chuyển', 24.0, 3300000, 9, 2, 1, '2024-03-30'),
('P1602', 1, N'Phòng an ninh tốt', N'An ninh tốt, có cửa, cổng', 19.0, 2500000, 9, 1, 1, '2024-03-30'),
('Q1701', 2, N'Phòng hiện đại 2024', N'Nội thất hiện đại, điều hòa mới', 29.0, 4100000, 2, 3, 1, '2024-04-01'),
('Q1702', 2, N'Phòng lâm chiêm', N'Lâm chiêm, không khí trong lành', 22.0, 2900000, 2, 2, 1, '2024-04-01'),
('R1801', 3, N'Phòng tối tân', N'Tối tân, đủ tiện nghi', 33.0, 4400000, 3, 3, 3, '2024-04-05'),
('R1802', 3, N'Phòng cho người bận', N'Cho người bận, sạch sẽ đủ', 21.0, 2800000, 3, 2, 1, '2024-04-05'),
('S1901', 4, N'Phòng presidential', N'Presidential, đẳng cấp cao', 52.0, 8200000, 4, 5, 4, '2024-04-10'),
('S1902', 4, N'Phòng quen thuộc', N'Quen thuộc, lâu nay không thay đổi', 26.0, 3700000, 4, 2, 1, '2024-04-10'),
('T2001', 5, N'Phòng warm', N'Ấm áp, chủ phòng tốt bụng', 23.0, 3200000, 10, 2, 1, '2024-04-15'),
('T2002', 5, N'Phòng minimal', N'Minimal, tối giản, sạch sẽ', 20.0, 2700000, 10, 1, 1, '2024-04-15');

-- Liên kết phòng với tiện ích (15 dòng)
INSERT INTO RoomUtilities (RoomID, UtilityID) VALUES
(1, 1), (1, 2), (1, 3), (1, 4), (1, 5), -- A101: WiFi, AC, Fridge, Bed, Desk
(2, 1), (2, 2), (2, 4), (2, 10), -- A102: WiFi, AC, Bed, Security
(3, 1), (3, 2), (3, 3), (3, 4), (3, 5), (3, 6), (3, 7), -- B201: WiFi, AC, Fridge, Bed, Desk, Bathroom, Kitchen
(4, 1), (4, 4), (4, 5), -- B202: WiFi, Bed, Desk
(5, 1), (5, 2), (5, 4), (5, 5), (5, 8), (5, 9), (5, 10); -- C301: WiFi, AC, Bed, Desk, Washer, TV, Security

-- Thêm hình ảnh phòng (8 dòng)
INSERT INTO RoomImages (RoomID, ImageUrl, DisplayOrder, IsMainImage) VALUES
(1, '/images/room1_main.jpg', 1, 1),
(1, '/images/room1_bathroom.jpg', 2, 0),
(2, '/images/room2_main.jpg', 1, 1),
(3, '/images/room3_main.jpg', 1, 1),
(3, '/images/room3_kitchen.jpg', 2, 0),
(5, '/images/room5_main.jpg', 1, 1),
(5, '/images/room5_view.jpg', 2, 0),
(7, '/images/room7_main.jpg', 1, 1);

-- Thêm booking (8 dòng)
INSERT INTO Bookings (RoomID, UserID, BookingStatus, CheckInDate, Duration, DepositAmount, Notes, CreatedAt, ApprovedBy, ApprovedAt) VALUES
(1, 6, 'Approved', '2024-03-01', 6, 7000000, N'Thanh toán trước', '2024-02-20', 1, '2024-02-21'),
(2, 7, 'Approved', '2024-03-15', 12, 6000000, N'Có đồng ký gia đình', '2024-03-01', 1, '2024-03-02'),
(3, 8, 'Pending', '2024-04-01', 6, 9000000, N'Chờ xác nhận', '2024-03-15', NULL, NULL),
(4, 9, 'Approved', '2024-02-01', 3, 7500000, '', '2024-01-28', 2, '2024-01-29'),
(5, 10, 'Approved', '2024-02-15', 12, 13000000, N'Gia đình 5 người', '2024-02-10', 3, '2024-02-11'),
(6, 11, 'Rejected', '2024-03-20', 6, 4000000, N'Không phù hợp', '2024-03-10', 4, '2024-03-11'),
(7, 12, 'Approved', '2024-01-20', 24, 16000000, N'Hợp đồng dài hạn', '2024-01-15', 4, '2024-01-16'),
(8, 13, 'Cancelled', '2024-04-10', 6, 7600000, N'Tìm được phòng khác', '2024-03-25', NULL, NULL);

-- Thêm hợp đồng (6 dòng) - Tự động tạo khi Booking Approved
INSERT INTO Contracts (BookingID, ContractNumber, StartDate, EndDate, RentalPrice, DepositAmount, Status, CreatedAt) VALUES
(1, 'CT-001-202403', '2024-03-01', '2024-09-01', 3500000, 7000000, 'Active', '2024-02-21'),
(2, 'CT-002-202403', '2024-03-15', '2025-03-15', 3000000, 6000000, 'Active', '2024-03-02'),
(4, 'CT-003-202402', '2024-02-01', '2024-05-01', 2500000, 7500000, 'Active', '2024-01-29'),
(5, 'CT-004-202402', '2024-02-15', '2025-02-15', 5500000, 13000000, 'Active', '2024-02-11'),
(7, 'CT-005-202401', '2024-01-20', '2026-01-20', 8000000, 16000000, 'Active', '2024-01-16'),
(8, 'CT-006-202404', '2024-04-10', '2024-10-10', 3800000, 7600000, 'Terminated', '2024-03-25');

-- Thêm thanh toán/hóa đơn (9 dòng)
INSERT INTO Payments (ContractID, UserID, AdminID, InvoiceNumber, PaymentDate, Amount, PaymentStatus, PaymentMethod, DueDate, PaidDate, CreatedAt) VALUES
(1, 6, 1, 'INV-001-202403', '2024-03-01', 3800000, 'Paid', N'Chuyển khoản', '2024-03-05', '2024-03-04', '2024-02-25'),
(1, 6, 1, 'INV-002-202404', '2024-04-01', 3850000, 'Pending', N'Chuyển khoản', '2024-04-05', NULL, '2024-03-25'),
(2, 7, 1, 'INV-003-202403', '2024-03-15', 3300000, 'Paid', N'Tiền mặt', '2024-03-20', '2024-03-19', '2024-03-10'),
(3, 9, 2, 'INV-004-202402', '2024-02-01', 2700000, 'Paid', N'Chuyển khoản', '2024-02-05', '2024-02-05', '2024-01-30'),
(4, 10, 3, 'INV-005-202402', '2024-02-15', 5900000, 'Paid', N'Online', '2024-02-20', '2024-02-18', '2024-02-10'),
(5, 12, 4, 'INV-006-202401', '2024-01-20', 8500000, 'Paid', N'Chuyển khoản', '2024-01-25', '2024-01-24', '2024-01-15'),
(1, 6, 1, 'INV-007-202405', '2024-05-01', 3900000, 'Pending', N'Chuyển khoản', '2024-05-05', NULL, '2024-04-25'),
(2, 7, 1, 'INV-008-202404', '2024-04-15', 3350000, 'Pending', N'Tiền mặt', '2024-04-20', NULL, '2024-04-10'),
(4, 10, 3, 'INV-009-202403', '2024-03-15', 5950000, 'Pending', N'Online', '2024-03-20', NULL, '2024-03-10');

-- Thêm phí phụ (10 dòng)
INSERT INTO Fees (PaymentID, FeeName, FeeAmount, Description) VALUES
(1, N'Nước', 50000, N'Tiêu thụ nước tháng 3'),
(1, N'Điện', 150000, N'Tiêu thụ điện tháng 3'),
(1, N'Internet', 100000, N'Phí internet tháng 3'),
(2, N'Nước', 55000, N'Tiêu thụ nước tháng 4'),
(2, N'Điện', 165000, N'Tiêu thụ điện tháng 4'),
(3, N'Nước', 45000, N'Tiêu thụ nước tháng 3'),
(3, N'Điện', 140000, N'Tiêu thụ điện tháng 3'),
(3, N'Internet', 100000, N'Phí internet tháng 3'),
(4, N'Nước', 30000, N'Tiêu thụ nước tháng 2'),
(5, N'Điện', 180000, N'Tiêu thụ điện tháng 2');

-- Thêm đánh giá phòng (7 dòng)
INSERT INTO Reviews (RoomID, UserID, Rating, Comment, Status, CreatedAt) VALUES
(1, 6, 4.5, N'Phòng đẹp, sạch sẽ, chủ phòng tử tế', 'Approved', '2024-03-15'),
(2, 7, 4.0, N'Yên tĩnh, phù hợp với học tập', 'Approved', '2024-04-01'),
(4, 9, 3.5, N'Nhỏ nhưng cozy, giá hợp lý', 'Approved', '2024-02-15'),
(5, 10, 5.0, N'Phòng rất tốt, đủ tiện nghi, view đẹp', 'Approved', '2024-03-01'),
(7, 12, 4.8, N'Cao cấp, đáng giá tiền, dịch vụ tuyệt vời', 'Approved', '2024-02-10'),
(1, 12, 4.2, N'Tốt, gần chợ, giao thông tiện', 'Pending', '2024-04-05'),
(3, 8, 3.0, N'Bình thường, cần sửa một số chỗ', 'Rejected', '2024-04-15');

-- Thêm thông báo (8 dòng)
INSERT INTO Notifications (RecipientID, SenderID, Title, Message, Type, RelatedEntityType, RelatedEntityID, IsRead, CreatedAt) VALUES
(6, 1, N'Booking được phê duyệt', N'Booking phòng A101 của bạn đã được chấp thuận. Vui lòng liên hệ để ký hợp đồng', 'Booking', 'Booking', 1, 0, '2024-02-21'),
(7, 1, N'Booking được phê duyệt', N'Booking phòng A102 của bạn đã được chấp thuận', 'Booking', 'Booking', 2, 1, '2024-03-02'),
(6, 1, N'Hóa đơn thanh toán mới', N'Hóa đơn tháng 4 cho phòng A101. Số tiền: 3.850.000 VND. Hạn: 05/04/2024', 'Payment', 'Payment', 2, 0, '2024-03-25'),
(8, 3, N'Yêu cầu xác nhận', N'Booking phòng C301 đang chờ xác nhận từ bạn', 'Booking', 'Booking', 3, 1, '2024-03-15'),
(11, 4, N'Booking bị từ chối', N'Booking phòng C302 của bạn bị từ chối vì không phù hợp yêu cầu', 'Booking', 'Booking', 6, 1, '2024-03-11'),
(10, 3, N'Nhắc nhở thanh toán', N'Hóa đơn INV-009-202403 sắp hết hạn. Vui lòng thanh toán trước 20/03/2024', 'Payment', 'Payment', 9, 0, '2024-03-18'),
(12, 4, N'Hợp đồng hoạt động', N'Hợp đồng CT-005-202401 của bạn đã được ký kết. Mã hợp đồng: CT-005-202401', 'Contract', 'Contract', 5, 1, '2024-01-16'),
(6, NULL, N'Cập nhật hệ thống', N'Hệ thống sẽ bảo trì vào lúc 2:00 AM - 4:00 AM ngày 15/04/2024', 'System', NULL, NULL, 0, '2024-04-10');
GO

-- =====================================================
-- TRIGGERS (Đảm bảo consistency và business logic)
-- =====================================================

-- Trigger 1: Đảm bảo Rooms với StatusID = 'Rented' phải có CurrentTenantID
-- và ngược lại, StatusID ≠ 'Rented' phải có CurrentTenantID = NULL
CREATE TRIGGER TR_Rooms_ValidateStatus
ON Rooms
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Kiểm tra 1: StatusID = 'Rented' (2) PHẢI có CurrentTenantID NOT NULL
    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.StatusID = 2 AND i.CurrentTenantID IS NULL
    )
    BEGIN
        RAISERROR('Phòng với trạng thái Rented phải có CurrentTenantID', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    
    -- Kiểm tra 2: StatusID ≠ 'Rented' (2) PHẢI có CurrentTenantID = NULL
    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.StatusID != 2 AND i.CurrentTenantID IS NOT NULL
    )
    BEGIN
        RAISERROR('Phòng không ở trạng thái Rented phải có CurrentTenantID = NULL', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- Trigger 2: Khi Booking status thay đổi, tự động cập nhật Room status
-- Xử lý 3 trường hợp: Approved, Rejected, Cancelled
CREATE TRIGGER TR_Bookings_StatusUpdateRoom
ON Bookings
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF UPDATE(BookingStatus)
    BEGIN
        -- Trường hợp 1: BookingStatus = 'Approved' ⟹ Room.StatusID = 'Rented' (2)
        UPDATE Rooms
        SET StatusID = 2, -- Rented
            CurrentTenantID = b.UserID,
            UpdatedAt = GETDATE()
        FROM Rooms r
        INNER JOIN inserted b ON r.RoomID = b.RoomID
        WHERE b.BookingStatus = 'Approved' AND r.StatusID != 2;
        
        -- Trường hợp 2: BookingStatus = 'Rejected' hoặc 'Cancelled' 
        -- ⟹ Room.StatusID = 'Available' (1)
        UPDATE Rooms
        SET StatusID = 1, -- Available
            CurrentTenantID = NULL,
            UpdatedAt = GETDATE()
        FROM Rooms r
        INNER JOIN inserted b ON r.RoomID = b.RoomID
        WHERE b.BookingStatus IN ('Rejected', 'Cancelled') AND r.StatusID = 2;
    END
END;
GO

-- =====================================================
-- QUY TẮC VÀ RÀNG BUỘC DỮ LIỆU
-- =====================================================
/*
1. NGUYÊN TẮC TOÀN VẸN THAM CHIẾU (Referential Integrity):
   - Tất cả khóa ngoài được thiết lập để đảm bảo dữ liệu nhất quán
   - Cascading delete áp dụng cho các bảng phụ thuộc
   
2. CHUẨN HÓA DỮ LIỆU (Normalization - 3NF):
   - Bảng Addresses riêng: loại bỏ redundancy địa chỉ từ Users/Rooms
   - Không có derived attributes: TotalPrice xóa từ Bookings
   - Tất cả non-key attributes phụ thuộc hoàn toàn vào primary key
   
3. RÀNG BUỘC KIỂM SOÁT (Check Constraints):
   - Role: 0 = Admin, 1 = User
   - Price, Area, Amount: phải > 0
   - Rating: từ 1 đến 5
   - PaymentStatus: 'Pending', 'Paid', 'Overdue', 'Cancelled'
   - BookingStatus: 'Pending', 'Approved', 'Rejected', 'Cancelled'
   - Contract.Status: 'Active', 'Expired', 'Terminated'
   
4. RÀNG BUỘC DUY NHẤT (Unique Constraints):
   - Email, Username (không trùng lặp)
   - RoomNumber, RoomUtility, ContractNumber, InvoiceNumber
   
5. TRIGGERS (Đảm bảo Business Logic):
   - TR_Rooms_ValidateStatus: 
     * StatusID = 'Rented' (2) ⟹ CurrentTenantID NOT NULL
     * StatusID ≠ 'Rented' ⟹ CurrentTenantID MUST NULL
   - TR_Bookings_StatusUpdateRoom: 
     * BookingStatus = 'Approved' ⟹ Room.StatusID = 'Rented' (2), CurrentTenantID = UserID
     * BookingStatus = 'Rejected' hoặc 'Cancelled' ⟹ Room.StatusID = 'Available' (1), CurrentTenantID = NULL
   
6. DẤU THỜI GIAN (Timestamps):
   - CreatedAt: không bao giờ thay đổi
   - UpdatedAt: được cập nhật ở application layer hoặc mỗi lần INSERT/UPDATE
   - LastLoginAt: cập nhật khi user đăng nhập
   - Hỗ trợ audit trail và theo dõi các thay đổi
   - LƯU Ý: Không dùng AFTER UPDATE triggers để cập nhật UpdatedAt vì gây vòng lặp vô hạn
   
7. BẢNG TRUNG GIAN:
   - RoomUtilities: quản lý mối quan hệ n-n giữa Rooms và Utilities
   
8. PHÒNG TRỌ (Rooms):
   - Có khóa ngoài đến Admin (quản lý)
   - Có khóa ngoài đến CurrentTenant (người thuê hiện tại)
   - Có khóa ngoài đến Addresses (địa chỉ tập trung)
   - Quy tắc xử lý: 
     * Khi Booking được Approved → cập nhật CurrentTenant và StatusID = 'Rented'
     * Khi Booking bị Rejected/Cancelled → CurrentTenantID = NULL, StatusID = 'Available'
     * Trigger kiểm tra: Rented ⟹ CurrentTenantID NOT NULL, Non-Rented ⟹ CurrentTenantID NULL
   
9. THANH TOÁN (Payments):
   - Liên kết với Contract (hợp đồng)
   - Liên kết với User (người thuê)
   - Liên kết với Admin (người tạo hóa đơn)
   - Bảng Fees để quản lý các khoản phí phụ
   - PaymentDate lưu ngày đầu tháng để dễ tính toán và so sánh
   
10. BẢNG TOKENS:
    - Hỗ trợ xác thực email và khôi phục mật khẩu
    - Có thời gian hết hạn (ExpiresAt)
    - Có trạng thái IsUsed để theo dõi token đã được sử dụng
*/


-- =====================================================
-- 17. THÊM DỮ LIỆU CÒN THIẾU
-- =====================================================

-- Thêm Activity Logs (10 dòng)
INSERT INTO ActivityLogs (UserID, ActionType, EntityType, EntityID, OldValues, NewValues, IPAddress, Description, CreatedAt) VALUES
(6, 'LOGIN', 'User', 6, NULL, NULL, '192.168.1.10', N'User user_thanh đăng nhập thành công', '2024-02-20 08:00:00'),
(6, 'CREATE', 'Booking', 1, NULL, '{"RoomID": 1, "Status": "Pending"}', '192.168.1.10', N'User user_thanh tạo booking mới', '2024-02-20 08:30:00'),
(1, 'APPROVE', 'Booking', 1, '{"Status": "Pending"}', '{"Status": "Approved"}', '192.168.1.100', N'Admin duyệt booking #1', '2024-02-21 09:00:00'),
(NULL, 'CREATE', 'Payment', 1, NULL, '{"Amount": 3800000}', '127.0.0.1', N'Hệ thống tạo hóa đơn tự động', '2024-02-25 00:00:00'),
(6, 'UPDATE', 'Payment', 1, '{"Status": "Pending"}', '{"Status": "Paid"}', '192.168.1.10', N'User user_thanh thanh toán hóa đơn #1', '2024-03-04 10:00:00'),
(7, 'CREATE', 'Review', 2, NULL, '{"RoomID": 2, "Rating": 4}', '192.168.1.12', N'User user_linh đánh giá phòng', '2024-04-01 14:00:00'),
(1, 'APPROVE', 'Review', 2, '{"Status": "Pending"}', '{"Status": "Approved"}', '192.168.1.100', N'Admin duyệt đánh giá #2', '2024-04-01 15:00:00'),
(8, 'SEARCH', 'Room', NULL, NULL, '{"Criteria": "District 1"}', '192.168.1.15', N'User user_hoa tìm kiếm phòng', '2024-03-10 11:00:00'),
(11, 'CANCEL', 'Booking', 6, '{"Status": "Pending"}', '{"Status": "Cancelled"}', '192.168.1.20', N'User user_khanh hủy booking', '2024-03-10 16:00:00'),
(2, 'UPDATE', 'Room', 3, '{"Price": 4200000}', '{"Price": 4500000}', '192.168.1.101', N'Admin cập nhật giá phòng B201', '2024-01-20 10:00:00');
GO

-- =====================================================
-- 18. STORED PROCEDURES (LOGIC NGHIỆP VỤ)
-- =====================================================

-- 18.1. SP Tạo hợp đồng từ Booking (Được gọi tự động khi Approve Booking)
CREATE PROCEDURE sp_CreateContractFromBooking
    @BookingID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @RoomID INT, @UserID INT, @CheckInDate DATETIME, @Duration INT, @DepositAmount DECIMAL(18,2);
    DECLARE @RentalPrice DECIMAL(18,2);
    DECLARE @ContractNumber NVARCHAR(50);
    DECLARE @StartDate DATETIME, @EndDate DATETIME;
    
    -- Lấy thông tin từ Booking và Room
    SELECT 
        @RoomID = b.RoomID,
        @UserID = b.UserID,
        @CheckInDate = b.CheckInDate,
        @Duration = b.Duration,
        @DepositAmount = b.DepositAmount,
        @RentalPrice = r.Price
    FROM Bookings b
    JOIN Rooms r ON b.RoomID = r.RoomID
    WHERE b.BookingID = @BookingID;
    
    -- Tính toán ngày kết thúc
    SET @StartDate = @CheckInDate;
    SET @EndDate = DATEADD(MONTH, @Duration, @StartDate);
    
    -- Tạo mã hợp đồng tự động: CT-{BookingID}-{YYYYMMDD}
    SET @ContractNumber = 'CT-' + CAST(@BookingID AS NVARCHAR(10)) + '-' + CONVERT(NVARCHAR(8), GETDATE(), 112);
    
    -- Insert vào Contracts
    INSERT INTO Contracts (BookingID, ContractNumber, StartDate, EndDate, RentalPrice, DepositAmount, Status)
    VALUES (@BookingID, @ContractNumber, @StartDate, @EndDate, @RentalPrice, @DepositAmount, 'Active');
    
    -- Ghi log
    INSERT INTO ActivityLogs (UserID, ActionType, EntityType, EntityID, Description)
    VALUES (NULL, 'CREATE', 'Contract', SCOPE_IDENTITY(), N'Hệ thống tự động tạo hợp đồng từ Booking #' + CAST(@BookingID AS NVARCHAR(10)));
END;
GO

-- 18.2. SP Duyệt Booking
CREATE PROCEDURE sp_ApproveBooking
    @BookingID INT,
    @AdminID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Kiểm tra Booking có tồn tại và đang Pending không
        IF NOT EXISTS (SELECT 1 FROM Bookings WHERE BookingID = @BookingID AND BookingStatus = 'Pending')
        BEGIN
            THROW 50001, N'Booking không tồn tại hoặc không ở trạng thái Pending.', 1;
        END

        -- Cập nhật Booking
        UPDATE Bookings
        SET BookingStatus = 'Approved',
            ApprovedBy = @AdminID,
            ApprovedAt = GETDATE(),
            UpdatedAt = GETDATE()
        WHERE BookingID = @BookingID;
        
        -- Gọi SP tạo hợp đồng
        EXEC sp_CreateContractFromBooking @BookingID;
        
        -- Trigger TR_Bookings_StatusUpdateRoom sẽ tự động chạy để update Room status
        
        -- Gửi thông báo cho User
        DECLARE @RecipientID INT;
        SELECT @RecipientID = UserID FROM Bookings WHERE BookingID = @BookingID;
        
        INSERT INTO Notifications (RecipientID, SenderID, Title, Message, Type, RelatedEntityType, RelatedEntityID)
        VALUES (@RecipientID, @AdminID, N'Đặt phòng được phê duyệt', N'Yêu cầu đặt phòng của bạn đã được chấp thuận. Hợp đồng đã được tạo.', 'Booking', 'Booking', @BookingID);
        
        -- Ghi log
        INSERT INTO ActivityLogs (UserID, ActionType, EntityType, EntityID, Description)
        VALUES (@AdminID, 'APPROVE', 'Booking', @BookingID, N'Admin duyệt Booking #' + CAST(@BookingID AS NVARCHAR(10)));
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 18.3. SP Tạo Token xác thực Email
CREATE PROCEDURE sp_CreateEmailVerificationToken
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Token NVARCHAR(255) = NEWID(); -- Tạo GUID ngẫu nhiên làm token
    DECLARE @ExpiresAt DATETIME = DATEADD(HOUR, 24, GETDATE()); -- Hết hạn sau 24h

    INSERT INTO EmailVerificationTokens (UserID, Token, ExpiresAt)
    VALUES (@UserID, @Token, @ExpiresAt);
    
    -- Trả về token để gửi email
    SELECT @Token AS VerificationToken;
END;
GO

-- 18.4. SP Đăng ký người dùng mới
CREATE PROCEDURE sp_RegisterUser
    @Username NVARCHAR(50),
    @Email NVARCHAR(100),
    @PasswordHash NVARCHAR(255),
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @PhoneNumber NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            -- Insert User
            INSERT INTO Users (Username, Email, PasswordHash, FirstName, LastName, PhoneNumber, Role, IsEmailVerified, IsActive)
            VALUES (@Username, @Email, @PasswordHash, @FirstName, @LastName, @PhoneNumber, 1, 0, 1); -- Role 1 = User
            
            DECLARE @NewUserID INT = SCOPE_IDENTITY();
            
            -- Tạo token xác thực
            EXEC sp_CreateEmailVerificationToken @NewUserID;
            
            -- Ghi log
            INSERT INTO ActivityLogs (UserID, ActionType, EntityType, EntityID, Description)
            VALUES (@NewUserID, 'CREATE', 'User', @NewUserID, N'Người dùng đăng ký tài khoản mới');
            
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 18.5. SP Tạo Token Reset Mật khẩu
CREATE PROCEDURE sp_CreatePasswordResetToken
    @Email NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @UserID INT;
    
    SELECT @UserID = UserID FROM Users WHERE Email = @Email;
    
    IF @UserID IS NOT NULL
    BEGIN
        DECLARE @Token NVARCHAR(255) = NEWID();
        DECLARE @ExpiresAt DATETIME = DATEADD(HOUR, 24, GETDATE());
        
        -- Vô hiệu hóa các token cũ
        UPDATE PasswordResetTokens SET IsUsed = 1 WHERE UserID = @UserID;
        
        INSERT INTO PasswordResetTokens (UserID, Token, ExpiresAt)
        VALUES (@UserID, @Token, @ExpiresAt);
        
        -- Trả về token và UserID
        SELECT @Token AS ResetToken, @UserID AS UserID;
    END
    ELSE
    BEGIN
        -- Không tìm thấy email, có thể trả về lỗi hoặc silent fail (để bảo mật)
        -- Ở đây chọn trả về NULL để app xử lý
        SELECT NULL AS ResetToken, NULL AS UserID;
    END
END;
GO

-- 18.6. SP Tạo Hóa đơn hàng tháng
CREATE PROCEDURE sp_CreateInvoice
    @ContractID INT,
    @Month INT,
    @Year INT,
    @FeesAmount DECIMAL(18,2) = 0, -- Tổng phí phụ
    @PaymentMethod NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @UserID INT, @AdminID INT, @RentalPrice DECIMAL(18,2);
        DECLARE @InvoiceNumber NVARCHAR(50);
        DECLARE @PaymentDate DATE = CAST(CAST(@Year AS VARCHAR) + '-' + CAST(@Month AS VARCHAR) + '-01' AS DATE);
        DECLARE @DueDate DATETIME = DATEADD(DAY, 5, @PaymentDate); -- Hạn ngày 5 hàng tháng
        DECLARE @TotalAmount DECIMAL(18,2);
        
        -- Lấy thông tin hợp đồng
        SELECT 
            @UserID = c.BookingID, -- Cần join lại Bookings để lấy UserID chính xác hơn
            @RentalPrice = c.RentalPrice,
            @AdminID = r.AdminID
        FROM Contracts c
        JOIN Bookings b ON c.BookingID = b.BookingID
        JOIN Rooms r ON b.RoomID = r.RoomID
        WHERE c.ContractID = @ContractID;
        
        -- Sửa lại lấy UserID từ Bookings
        SELECT @UserID = UserID FROM Bookings WHERE BookingID = (SELECT BookingID FROM Contracts WHERE ContractID = @ContractID);

        SET @TotalAmount = @RentalPrice + @FeesAmount;
        SET @InvoiceNumber = 'INV-' + CAST(@ContractID AS NVARCHAR(10)) + '-' + CAST(@Year AS NVARCHAR(4)) + RIGHT('00' + CAST(@Month AS NVARCHAR(2)), 2);
        
        -- Check duplicate
        IF EXISTS (SELECT 1 FROM Payments WHERE InvoiceNumber = @InvoiceNumber)
        BEGIN
            THROW 50002, N'Hóa đơn cho tháng này đã tồn tại.', 1;
        END
        
        -- Insert Payment
        INSERT INTO Payments (ContractID, UserID, AdminID, InvoiceNumber, PaymentDate, Amount, PaymentStatus, PaymentMethod, DueDate)
        VALUES (@ContractID, @UserID, @AdminID, @InvoiceNumber, @PaymentDate, @TotalAmount, 'Pending', @PaymentMethod, @DueDate);
        
        DECLARE @PaymentID INT = SCOPE_IDENTITY();
        
        -- Gửi thông báo
        INSERT INTO Notifications (RecipientID, SenderID, Title, Message, Type, RelatedEntityType, RelatedEntityID)
        VALUES (@UserID, @AdminID, N'Hóa đơn mới', N'Bạn có hóa đơn mới tháng ' + CAST(@Month AS NVARCHAR(2)) + '/' + CAST(@Year AS NVARCHAR(4)), 'Payment', 'Payment', @PaymentID);
        
        -- Ghi log
        INSERT INTO ActivityLogs (UserID, ActionType, EntityType, EntityID, Description)
        VALUES (@AdminID, 'CREATE', 'Payment', @PaymentID, N'Tạo hóa đơn ' + @InvoiceNumber);

        SELECT @PaymentID AS NewPaymentID;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
