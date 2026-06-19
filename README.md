# ProstarM Inventory Management System

A comprehensive branch-wise stock tracking system with isolated good, rejected, damaged, buyback, and scrap inventory management.

## Features

- **Branch-wise Stock Tracking**: Manage inventory across multiple branches
- **Inventory Conditions**: Track goods in different conditions (Good, Rejected, Damaged, Buyback, Scrap)
- **User Management**: Role-based access control (Admin, Store, Viewer)
- **Stock Transactions**: Record and track all inventory movements
- **Data Import**: Import existing inventory from Excel files
- **Authentication**: Secure JWT-based authentication

## Getting Started

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/prostar-inventory.git
   cd prostar-inventory
   ```

2. **Create virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Run the application**
   ```bash
   python app.py
   ```

5. **Access the application**
   ```
   http://127.0.0.1:8000/
   ```

### Demo Credentials

- **Admin**: admin@prostarm.com / Admin@12345
- **Store**: store@prostarm.com / Store@12345
- **Viewer**: viewer@prostarm.com / Viewer@12345

## Deployment on Vercel

### Prerequisites
- GitHub account
- Vercel account (free)
- Git installed locally

### Steps

1. **Create GitHub Repository**
   - Go to https://github.com/new
   - Create a new repository named `prostar-inventory`
   - Do NOT initialize with README, .gitignore, or license

2. **Push code to GitHub**
   ```bash
   cd d:\ProstarM\ Inventory\ system
   git init
   git add .
   git commit -m "Initial commit: ProstarM Inventory Management System"
   git branch -M main
   git remote add origin https://github.com/your-username/prostar-inventory.git
   git push -u origin main
   ```

3. **Deploy to Vercel**
   - Go to https://vercel.com/import
   - Connect your GitHub account
   - Select the `prostar-inventory` repository
   - Vercel will auto-detect the project
   - Click "Deploy"

4. **Set Environment Variables in Vercel**
   - Go to Project Settings → Environment Variables
   - Add: `PROSTARM_SECRET` = your-secret-key
   - Redeploy the project

5. **Access Your Deployed App**
   - Your app will be available at `https://your-project.vercel.app`

## Project Structure

```
prostar-inventory/
├── app.py                 # Main application
├── requirements.txt       # Python dependencies
├── vercel.json           # Vercel configuration
├── api/
│   └── index.py          # Vercel serverless handler
├── data/
│   └── prostarm_inventory.db   # SQLite database
├── static/
│   ├── index.html        # Login page
│   ├── app.js            # Frontend JavaScript
│   └── styles.css        # Styling
├── docs/
│   ├── README.md         # Documentation
│   ├── backend/          # Backend docs
│   ├── database/         # Database schema & ERD
│   └── frontend/         # Frontend wireframes
└── .gitignore           # Git ignore rules
```

## Database

The system uses SQLite for data storage with the following main tables:
- **branches**: Warehouse and branch locations
- **users**: User accounts with roles
- **categories**: Product categories
- **materials**: Stock items
- **inventory_balances**: Current stock levels by condition
- **stock_transactions**: Transaction history
- **stock_transaction_lines**: Transaction line items

## Technologies Used

- **Backend**: Python (HTTP Server)
- **Database**: SQLite3
- **Frontend**: HTML5, CSS3, JavaScript
- **Authentication**: JWT (JSON Web Tokens)
- **Hosting**: Vercel (Serverless)

## Environment Variables

- `PROSTARM_SECRET`: Secret key for JWT signing (change before production)
- `HOST`: Server host (default: 127.0.0.1)
- `PORT`: Server port (default: 8000)

## Support

For issues or questions, please create an issue in the repository.

## License

All rights reserved.
