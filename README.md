# <img src="https://github.com/OwnYourData/app-dec112/raw/master/app/assets/images/app-dec112.png" width="92"> DEC112    

The OwnYourData DEC112 App displays personal information provided during an emergency chat and allows editing. Read more about DEC112 on the official website here: https://www.dec112.at/en/. The following screenshot shows the DEC112 App.

<img src="https://github.com/OwnYourData/app-dec112/raw/master/app/assets/images/screenshot1.png">

### OwnYourData Data Vault

The DEC112 App is deployed in your OwnYourData Data Vault. Usually you have to pass on your data to the operators of web services and apps in order to be able to use them. OwnYourData, however, turns the tables: You keep all your data and you keep them in your own data vault. You bring apps (data collection, algorithms and visualization) to you in the data vault.

more information: https://www.ownyourdata.eu    
for developer: https://www.ownyourdata.eu/developer/    
Docker images: https://hub.docker.com/r/oydeu/app-dec112    

&nbsp;    

## Installation    

Install the DEC112 App in the Data Vault Plugin page (https://data-vault.eu/en/plugins) by clicking "+ Add Plugin" and either selecting "DEC112" from the available list of pre-defined plugins or paste the Manifest [available here](https://github.com/OwnYourData/app-dec112/raw/master/config/dec112_en.json).

## Data Structure    

The repo (default `oyd.dec112`) uses the following structure:    
```json
{
    "did": "{left empty for now}",
    "initialized": false,
    "additionalData": ["empty for now"],
    "dataSavingMethod": "did",
    "title": "title",
    "surName": "first name",
    "familyName": "last name",
    "street": "street",
    "zipCode": "ZIP code",
    "city": "city",
    "country": "two letter country code",
    "phone": "phone number",
    "mail": "email address"
}
```

## Improve the Consent Information App

Please report bugs and suggestions for new features using the [GitHub Issue-Tracker](https://github.com/OwnYourData/app-dec112/issues) and follow the [Contributor Guidelines](https://github.com/twbs/ratchet/blob/master/CONTRIBUTING.md).

If you want to contribute, please follow these steps:

1. Fork it!
2. Create a feature branch: `git checkout -b my-new-feature`
3. Commit changes: `git commit -am 'Add some feature'`
4. Push into branch: `git push origin my-new-feature`
5. Send a Pull Request

&nbsp;    

## License

[MIT License 2020 - OwnYourData.eu](https://raw.githubusercontent.com/OwnYourData/app-dec112/master/LICENSE)