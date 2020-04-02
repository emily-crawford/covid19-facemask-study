COVID-19 Face Mask Study
-----------------------------------------------

* [Introduction](#introduction)
* [Setup](#setup)
    * [Prerequisites](#prerequisites)
    * [Procedures](#procedures)
* [Data](#data)
* [Contact Us](#contact-us)
* [People](#people)

Introduction
------------

These do-files replicate the empirical analysis in "The Case for Universal Cloth Mask Adoption & Policies to Increase the Supply of Medical Masks for Health Workers".

Due to the urgent nature of the question, the data cleaning and analysis were done over a period of 2 days. If you find any errors, please notify us immediately at the contact information below.


Setup
------------
Follow the steps below to get the code running on your local machine.

### Prerequisites
The data cleaning and analysis for this project is completed in Stata. As of April 2020, the latest version of Stata is Stata-16.

### Procedure
To get the code running, create a directory of the following structure:
* _drop_: Contains makefile `makedata.do`
	* _datadir_: Contains datafiles `OxCGRT_Download_latest_data.csv`, `Reports.csv`, `graph_mask_requirements_v3B`, and `countrygraphG`.
	* _logdir_: The Stata log files will be output here.

Data
------------
Our analysis relies on the following data sources.

### Oxford COVID-19 Government Response Tracker
Oxford University has compiled a dataset of publicly available information on government response to the COVID-19 outbreak. As of the time writing, this dataset is live and being updated as the situation around the world develops. For more information on this data, please see the Oxford COVID-19 Government Response Tracker [website](https://www.bsg.ox.ac.uk/research/research-projects/oxford-covid-19-government-response-tracker).

Our code and findings are based on the data released as of March 30, 2020.

### COVID-19 Israel Team
The COVID-19 Israel team published a dataset on international statistics relating to COVID-19, including confirmed number of cases, deaths, recoveries, and persons tested. As of April 1, 2020 this dataset is live; we rely on the version downloaded as of April 1st, 2020. For much more information on this dataset, please see the COVID-19 Israel team [website](http://covidil.org/dashboard) and [github repository](https://github.com/COVID-19-Israel/Covid-19-data).


### Face Mask Policies
To fill in the gaps of public data on both (1) enacted face mask policies in response to the COVID-19 outbreak as well as (2) the general social norms of wearing face masks, our team has crowdsourced this data via Twitter. If you would like to contribute to the public knowledge of face mask norms and policies in your region, please visit the [spreadsheet].(https://docs.google.com/spreadsheets/d/1dG3CaE9u180aDQri8haCllggJxWB-pdyEIZGUnsX-Dc/edit)

Contact Us
----------
For any questions, comments, or suggestions please reach out to:
Emily Crawford (emily.crawford@yale.edu).

People
------

Jason Abaluck

    email:       jason.abaluck@yale.edu
    institution: Yale School of Management
    role:        Author

Emily L. Crawford

    email:       emily.crawford@yale.edu
    institution: Yale School of Management
    role:        Project Manager

