import ballerinax/mysql;
import wso2healthcare/healthcare.fhir.r4.uscore501;
import wso2healthcare/healthcare.fhir.r4;
import ballerina/log;
import ballerina/sql;
import ballerina/http;

public type Patient record {|

    string patient_id;
    string identifier_system;
    string identifier_value;
    string first_name;
    string last_name;
    string name_use?;
    string telecom_system?;
    string telecom_value?;
    string telecom_use?;
    string gender;
    string birthdate?;
    string address_use?;
    string address_line?;
    string address_city?;
    string address_postalcode?;
|};

configurable string USER = ?;
configurable string PASSWORD = ?;
configurable string HOST = ?;
configurable int PORT = ?;
configurable string DATABASE = ?;

final mysql:Client dbClient = check new (user = USER, password = PASSWORD, host = HOST, port = PORT, database = DATABASE);

isolated function addPatient(json patientPayload) returns uscore501:USCorePatientProfile|r4:FHIRError? {

    do {
        anydata parsedResult = check r4:parse(patientPayload, uscore501:USCorePatientProfile);
        uscore501:USCorePatientProfile patient = check parsedResult.ensureType();

        string[]? givenNames = [];
        string givenName = "";
        string familyName = "";
        string identifierSystem = "";
        string identifierValue = "";
        string namesUse = "";
        string telecomSystem = "";
        string telecomValue = "";
        string telecomUse = "";
        string[]? addressLines = [];
        string? addressLine = "";
        string? addressCity = "";
        string? addressPostalCode = "";
        string addressUse = "";

        r4:HumanName[]? humanNames = patient.name;
        if humanNames is r4:HumanName[] {
            familyName = <string>humanNames[0].family;
            namesUse = <string>humanNames[0].use;
            givenNames = humanNames[0].given;
            if givenNames is string[] {
                givenName = givenNames[0];
            }
        }

        r4:Identifier[]? identifiers = patient.identifier;
        if identifiers is r4:Identifier[] {
            identifierSystem = <string>identifiers[0].system;
            identifierValue = <string>identifiers[0].value;
        }

        r4:ContactPoint[]? telecoms = patient.telecom;
        if telecoms is r4:ContactPoint[] {
            telecomSystem = <string>telecoms[0].system;
            telecomValue = <string>telecoms[0].value;
            telecomUse = <string>telecoms[0].use;
        }

        r4:Address[]? addresses = patient.address;
        if addresses is r4:Address[] {
            addressCity = addresses[0].city;
            addressUse = <string>addresses[0].use;
            addressPostalCode = addresses[0].postalCode;
            addressLines = addresses[0].line;
            if addressLines is string[] {
                addressLine = addressLines[0];
            }
        }

        sql:ExecutionResult result = check dbClient->execute(
        `INSERT INTO patients (patient_id, identifier_system, identifier_value, first_name, last_name, name_use, telecom_system, telecom_value, telecom_use, gender, birthdate, address_use, address_line, address_city, address_postalcode)
        VALUES (${patient.id}, ${identifierSystem}, ${identifierValue}, ${givenName}, ${familyName}, ${namesUse}, ${telecomSystem}, ${telecomValue},${telecomUse},${patient.gender}, ${patient.birthDate}, ${addressUse}, ${addressLine}, ${addressCity}, ${addressPostalCode})`
        );
        log:printInfo(result.toString());
        return patient;
    }
    
    on fail error parseError {
        log:printError(string `Error occurred while parsing : ${parseError.message()}`, parseError);
    }

}

isolated function getPatient(string id) returns uscore501:USCorePatientProfile|r4:FHIRError? {
    do {
        Patient patient = check dbClient->queryRow(`SELECT * FROM patients WHERE patient_id = ${id}`);

        r4:PatientGender? patientGender = checkGender(patient.gender);
        r4:AddressUse? addressUse = checkAddressUse(<string>patient.address_use);

        uscore501:USCorePatientProfile|r4:FHIRError? fhirPatient = implementUSCoreFHIRPatient(patient.patient_id, patient.identifier_system, patient.identifier_value, [patient.first_name], patient.last_name, <r4:HumanNameUse>patient.name_use, <r4:PatientGender>patientGender, <string>patient.birthdate, <r4:ContactPointSystem>patient.telecom_system, <string>patient.telecom_value, <r4:ContactPointUse>patient.telecom_use, <string>patient.address_city, <string>patient.address_postalcode, <r4:AddressUse>addressUse);

        return fhirPatient;

    } on fail var e {
        r4:FHIRError fhirError = r4:createFHIRError(e.toString(), r4:CODE_SEVERITY_FATAL, r4:CODE_TYPE_INFORMATIONAL, httpStatusCode = http:STATUS_NOT_FOUND);
        return fhirError;
    }
}

isolated function getAllPatients() returns r4:Bundle|r4:FHIRError?|error {
    do {
        stream<Patient, error?> resultStream = dbClient->query(`SELECT * FROM patients`);
        Patient[] patients = [];
        check from Patient patient in resultStream
            do {
                patients.push(patient);
            };
        check resultStream.close();

        r4:BundleEntry[] entries = [];
        foreach Patient patient in patients {
            r4:PatientGender? patientGender = checkGender(patient.gender);
            r4:AddressUse? addressUse = checkAddressUse(<string>patient.address_use);

            uscore501:USCorePatientProfile|r4:FHIRError? fhirPatient = implementUSCoreFHIRPatient(patient.patient_id, patient.identifier_system, patient.identifier_value, [patient.first_name], patient.last_name, <r4:HumanNameUse>patient.name_use, <r4:PatientGender>patientGender, <string>patient.birthdate, <r4:ContactPointSystem>patient.telecom_system, <string>patient.telecom_value, <r4:ContactPointUse>patient.telecom_use, <string>patient.address_city, <string>patient.address_postalcode, <r4:AddressUse>addressUse);

            entries.push({
                'resource: check fhirPatient
            });
        }

        r4:Bundle bundle = {
            'type: r4:BUNDLE_TYPE_SEARCHSET,
            entry: entries
        };

        log:printInfo(bundle.toString());
        return bundle;

    } on fail error parseError {
        log:printError(string `Error occurred while parsing : ${parseError.message()}`, parseError);
    }

}
