# Room Rental Management

A comprehensive room rental management system built with ASP.NET MVC 5, featuring room listings, bookings, contracts, invoicing, and payment processing.

## Features

### Admin Dashboard
- Room management (create, edit, delete)
- Booking approval and management
- Contract management
- Invoice generation (single and monthly)
- User management
- Review moderation
- Payment tracking
- Activity logs
- Revenue reporting

### User Features
- Browse and search available rooms
- Create and manage bookings
- View contracts
- Track invoices and payments
- Manage user profile
- View activity history

### Guest Features
- Search and filter rooms
- View room details
- Register and login
- Request bookings

## Technology Stack

- **Framework**: ASP.NET MVC 5
- **ORM**: Entity Framework 6.2.0
- **Database**: SQL Server
- **Frontend**: Razor Views, Tailwind CSS, Bootstrap 5
- **Libraries**: jQuery, jQuery Validation

## System Requirements

- .NET Framework 4.8.1 or higher
- SQL Server 2016 or higher
- Visual Studio 2019 or higher (for development)
- IIS 10.0 or higher (for deployment)

## Installation

### Quick Start

#### Prerequisites
- .NET Framework 4.8.1
- SQL Server 2016 or higher
- Visual Studio 2019 or higher

#### Steps

**1. Clone the repository**
```bash
git clone https://github.com/huyhung1205/room-rental-management.git
cd room-rental-management
```

**2. Setup Database**
- Open `QuanLyThuePhongTro.sql` in SQL Server Management Studio
- Execute the script to create the database and tables
- Update the connection string in `Web.config` if using a different SQL Server instance:
  ```xml
  <add name="DbContext_65133295" connectionString="data source=YOUR_SERVER;initial catalog=QuanLyThuePhongTro;integrated security=True;" providerName="System.Data.SqlClient" />
  ```

**3. Configure Email Settings**
- Open `Web.config`
- Update the email configuration (see Configuration section below)

**4. Open in Visual Studio**
- Open `Project_65133295.sln`
- Build the solution (Ctrl + Shift + B)
- Set `Project_65133295` as the startup project
- Press F5 to run

**5. Default Login Credentials**
- Create test user through registration form, or
- Check database for existing test accounts

## Configuration

### Database Connection
Update the connection string in `Web.config` if your SQL Server is on a different server:
```xml
<connectionStrings>
    <add name="DbContext_65133295" connectionString="data source=YOUR_SERVER;initial catalog=QuanLyThuePhongTro;integrated security=True;" providerName="System.Data.SqlClient" />
</connectionStrings>
```

### Email Configuration (SMTP)
The application uses SMTP for sending emails. Configure your email settings in `Web.config`:

```xml
<appSettings>
    <add key="EmailHost" value="smtp.gmail.com" />
    <add key="EmailPort" value="587" />
    <add key="EmailUser" value="your-email@gmail.com" />
    <add key="EmailPassword" value="your-app-password" />
    <add key="EmailSenderName" value="Room Rental Management System" />
</appSettings>
```

#### For Gmail:
1. Enable 2-factor authentication on your Google account
2. Generate an App Password: https://support.google.com/accounts/answer/185833
3. Use the 16-character app password as `EmailPassword`
4. Use your full Gmail address as `EmailUser`

#### For Other Email Providers:
- Update `EmailHost` with your provider's SMTP server
- Update `EmailPort` (usually 587 for TLS or 465 for SSL)
- Use your email and password accordingly

## Project Structure

```
Project_65133295/
├── Areas/
│   ├── Admin/          # Admin dashboard and management
│   ├── User/           # User features
│   └── ...
├── Models/             # Database models and ViewModels
├── Controllers/        # API endpoints and page controllers
├── Views/              # Razor view templates
├── Content/            # CSS and stylesheets
├── Scripts/            # JavaScript files
└── App_Data/           # Local data storage
```

## User Roles

### Admin
- Full access to all features
- Manage rooms, users, bookings, contracts, invoices, and payments
- View analytics and reports

### User (Landlord/Property Owner)
- Manage their own rooms and bookings
- Create and manage contracts
- Generate invoices and track payments

### Guest (Tenant)
- Search and browse available rooms
- Create booking requests
- View their own bookings and contracts

## Database Schema

Key tables include:
- `Users` - User accounts and profiles
- `Rooms` - Room listings and details
- `RoomUtilities` - Amenities and utilities
- `Bookings` - Room booking requests
- `Contracts` - Rental agreements
- `Invoices` - Payment invoices
- `Payments` - Payment records
- `Reviews` - User reviews and ratings

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, open an issue on GitHub or contact support@roomrentalmanagement.com.

## Authors

- Your Name (@yourusername)

## Acknowledgments

- Bootstrap for CSS framework
- jQuery for JavaScript utilities
- Entity Framework for ORM support
