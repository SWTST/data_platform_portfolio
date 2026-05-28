# **(1.1)** Plan & Implement Data Platform Resources

## Sub-Sections

### Theory:

- [ ] **(1.11)** Deploy Azure SQL DB, Managed Instance, SQL on VMs — when to use each 
- [ ] **(1.12)** Automated deployment (ARM/Bicep templates)
- [ ] **(1.13)** Migration strategies — online vs offline, Azure Migrate, DMS
- [ ] **(1.14)** Table partitioning & database sharding concepts
- [ ] **(1.15)** Configuring scale & performance (DTUs, vCores, elastic pools, read replicas)

### Practical:
- [ ] **(1.16)** Deploy an Azure SQL Database using the Azure free tier
- [ ] **(1.17)** On SQL Express, create a partitioned table with sample data

### Applied:
- [ ] **(1.18)** Audit a sample SQL estate — document what's on-prem vs cloud


## **(1.11)** Deploy Azure SQL DB, Managed Instance, SQL on VMs — when to use each 

There are 3 products within the Azure SQL family:

- Azure SQL Database (PaaS)
  - Azure SQL Database Hyperscale
- Azure Managed Instances (PaaS)
- SQL Server on Azure VMs (IaaS)

Below is a table that compares how the responsibilities differ between each Azure SQL Product.

| Responsibility | Azure SQL Database | Azure SQL Managed Instance | SQL Server on Azure VM |
|---|---|---|---|
| **Physical Hardware** | Microsoft | Microsoft | Microsoft |
| **Networking (Host)** | Microsoft | Microsoft | Microsoft |
| **Operating System** | Microsoft | Microsoft | Customer |
| **OS Patching & Updates** | Microsoft | Microsoft | Customer |
| **SQL Server Installation** | Microsoft | Microsoft | Customer |
| **SQL Server Patching** | Microsoft | Microsoft | Customer |
| **High Availability** | Microsoft (built-in) | Microsoft (built-in) | Customer (configure Always On, FCIs, etc.) |
| **Automated Backups** | Microsoft (built-in) | Microsoft (built-in) | Customer (can use Azure Backup for SQL) |
| **Disaster Recovery** | Microsoft (geo-replication, auto-failover groups) | Microsoft (auto-failover groups) | Customer (configure manually) |
| **Database Creation & Design** | Customer | Customer | Customer |
| **Index & Query Tuning** | Customer (with built-in intelligence) | Customer (with built-in intelligence) | Customer |
| **Security & Access Control** | Customer | Customer | Customer |
| **Data Encryption (TDE)** | Microsoft (enabled by default) | Microsoft (enabled by default) | Customer (configure manually) |
| **Compliance & Auditing** | Shared | Shared | Customer |
| **Scaling** | Customer (choose tier/DTUs/vCores) | Customer (choose vCores) | Customer (resize VM) |

---
SQL Server on Azure VMs is IaaS and the others are PaaS. This means that it is the most configurable option but also comes with the most work and responsibility. The User has full control over everything other than the Network and Hardware.
        
Azure SQL Database and Azure SQL Managed Instance are offered and 'pre-built' by Microsoft. The user is only responsible for the database design including Performance tuning, Security and Scaling via the Azure portal.

## Requirements for Azure VMs vs PaaS Offerings

Many applications reqirue SQL Server on a VM. Some reasons include:

- **General Application Support and incompatibility** - For applications requiring an older version of SQL Server for Vendor Support. Also, some application services may have a requirement to be installed with the database instance in a manner that isn't compatible with PaaS offering.
- **Use of other SQL Server Services** - In order to maximise licensing, many users choose to run SSAS, SSIS, and/or SSRS on the same machine as the Database Engine.

## Versions of SQL Server available

Microsoft keeps images of all supported versions of SQL Server. If you require older versions that are covered by extended support, you'll need to install your own SQL Server Binaries.

## Backup Solutions

Currently, there are 2 key backup features for SQL Server on Azure VMs. These are:

- Backup to URL
- Azure Backup

**Backup to URL** allows your to backup your databases to Azure blob storage. **Azure Backup** provides a comprehensive backup solution that automatically manages your backups across your entire infrastructure.

## Deployment Options

All resources in Azure are managed and deployed through a common provider known as Azure Resource Manager (ARM). While there are various methods to deploy Azure resources, they ultimately converge into JSON documents called ARM templates, which serve as one of the deployment options for Azure resources.

The key distinction between these methods is that Azure Resource manager templates use a declarative deployment approach, which defines the desired structure and state of the resources to be deployed. In contrast, other methods are imperative, using procedural models to explicitly specify steps to be executed. For large-scale deployments, the declarative approach is preferable and should be adopted.

## Overview of Azure storage

In terms of Virtual Machines, there are four types of storage you can use:
- Standard (10-50ms)
- Standard SSD (5-10ms)
- Premium SSD (5-10ms)
- Ultra Disk (1-2ms)

For Production SQL Server data and transaction log files, you should use Premium SSD storage and Ultra Disk.

Premium storage, you see latencies of 5-10ms on a properly configured system. With Ultra Disk you should see latencies of 1-2ms. 

Standard storage can be used for database backups, as the performance is adequate for most backup and restore workloads.

## High Availability in Azure

Many organizations experience higher availability on Azure VMs than their previous On-Premise environments. Microsoft guarantees 99.9% uptime for a single instance Azure VM, when using Premium SSD or Ultra Disk.

Azure offers several features to support high availability including availability sets, availability zones, and load-balancing techniques that provide high availability by distributing incoming traffic among Virtual Machines.

## SQL Server enabled by Azure Arc

Azure Arc allows you to extend Azure management capabilities to instances running outside of Azure, whether that is on-premise or on other cloud services.

With Azure Arc, you can centrally manage and monitor your SQL Server instances through the Azure portal just like you would with Native Azure services. 

Additionally, Azure arc enables advanced features like automated updates, backup and restore, and disaster recovery for you SQL Server instances. By connecting SQL Instances to Azure Arc you can also take advantage of Azure's machine learning and artificial intelligence capabilities.
