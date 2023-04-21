import wso2healthcare/healthcare.fhir.r4;
import wso2healthcare/healthcare.fhir.r4.uscore501;

isolated function checkGender(string gender) returns r4:PatientGender? {
    r4:PatientGender? patientGender = r4:CODE_GENDER_UNKNOWN;
    if gender == "female" {
        patientGender = r4:CODE_GENDER_FEMALE;
    }
    else if gender == "male" {
        patientGender = r4:CODE_GENDER_MALE;
    }
    else if gender == "other" {
        patientGender = r4:CODE_GENDER_OTHER;
    }
    return patientGender;
}

isolated function checkAddressUse(string addressUse) returns r4:AddressUse? {
    r4:AddressUse? addressUseType = "home";

    if addressUse == "work" {
        addressUseType = "work";
    }
    else if addressUse == "temp" {
        addressUseType = "temp";
    }
    else if addressUse == "old" {
        addressUseType = "old";
    }
    else if addressUse == "billing" {
        addressUseType = "billing";
    }
    return addressUseType;
}

isolated function implementUSCoreFHIRPatient(string id, string identifierSystem, string identifierValue, string[] firstName, string lastName, r4:HumanNameUse nameUse, r4:PatientGender gender, string birthDate, r4:ContactPointSystem telecomSystem, string telecomValue, r4:ContactPointUse telecomUse, string addressCity, string addressPostalCode, r4:AddressUse addressUse) returns uscore501:USCorePatientProfile|r4:FHIRError? {

    uscore501:USCorePatientProfile fhirPatient = {
        id: id,
        identifier: [
            {
                system: identifierSystem,
                value: identifierValue
            }
        ],
        name: [
            {
                given: firstName,
                family: lastName,
                use: nameUse
            }
        ],
        gender: gender,
        birthDate: birthDate,
        telecom: [
            {
                system: <r4:ContactPointSystem?>telecomSystem,
                value: telecomValue,
                use: <r4:ContactPointUse?>telecomUse
            }
        ],
        address: [
            {
                use: addressUse,
                city: addressCity,
                postalCode: addressPostalCode
            }
        ]

    };
    return fhirPatient;
}
