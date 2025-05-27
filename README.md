# VolaryDDNS Update Script

![VolaryDDNS logo](https://static-content.volary.cloud/images/logo-long.png)

The **VolaryDDNS update script** is a lightweight, secure client-side tool designed to automate the process of keeping your dynamic DNS records current. It continuously monitors your device’s public IP address and updates your VolaryDDNS subdomain whenever the IP changes. This ensures your domain always resolves correctly, even when your ISP changes your IP.

The script is built for simplicity and security. It relies on token-based authentication to securely communicate with the VolaryDDNS backend, preventing unauthorized updates. Additionally, it is designed with minimal dependencies, making it easy to deploy on almost any Linux or Unix-like system.

---

## Overview

Dynamic DNS (DDNS) is essential for users who host servers or services on networks with frequently changing IP addresses. Traditional DNS records are static, so whenever your public IP changes, you would have to update the DNS manually to avoid downtime. The VolaryDDNS update script solves this by automating IP detection and DNS record updates with zero manual intervention.

Instead of configuring the script manually, VolaryDDNS provides a personalized version of the update script through its dashboard. When you log in and download your script, your unique subdomain and secure API token are already embedded, reducing setup errors and streamlining the process.

Once deployed, the script can be scheduled via `cron` or systemd timers to run at intervals, ensuring your DNS records stay accurate and your services remain accessible.

---

## Installation and Usage

For your convenience, the installation instructions, detailed usage guides, and troubleshooting tips are all available in the VolaryDDNS dashboard. This approach keeps the README concise and lets you follow up-to-date, step-by-step tutorials tailored specifically to your account.

---

## Contributing

Contributions to the VolaryDDNS update script are welcome! If you find a bug, have an improvement, or want to add a new feature, please follow these guidelines:

1. **Fork the repository**  
2. **Create a new branch** for your feature or bug fix (`git checkout -b feature-name`)  
3. **Commit your changes** with clear, descriptive messages  
4. **Push your branch** to your fork  
5. **Open a Pull Request (PR)** on the main repository explaining your changes and the motivation behind them  

Please ensure your code adheres to best practices and is thoroughly tested. Code reviews will be performed on all PRs before merging.

---

## License

This project is licensed under a custom license.

You are permitted to use and modify the script for personal, non-commercial purposes only. Redistribution, publishing, or sublicensing of this software to any third party other than the original repository is strictly prohibited.

See the [LICENSE](https://github.com/VolaryCloud/VolaryDDNS-updates/blob/main/LICENSE) file for full details.

---

## Support

If you encounter any issues or have questions, please open an issue on the [GitHub repository](https://github.com/VolaryCloud/VolaryDDNS-updates/issues).

For general help, feature requests, or community discussions, visit the VolaryDDNS [official website](https://ddns.volary.cloud) and join our community channels.

---

## Acknowledgments

Thanks to everyone who has contributed to VolaryDDNS and helped improve this update script. Your support and feedback are invaluable.

---

Made with ❤️ by Phillip Rødseth — [philliphat.com](https://philliphat.coom)
