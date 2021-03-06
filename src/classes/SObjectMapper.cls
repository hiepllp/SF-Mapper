public class SObjectMapper {
	private static Map<String,IFieldMapping> fieldMappingSource;
	static {
		fieldMappingSource = new Map<String, IFieldMapping>();
	}
	/**
	 * initializes mapping to be used in mapObject static method
	 * @param  objectName
	 * @param  fieldMapping
	 */
	public static void initialize(String objectName, IFieldMapping fieldMapping){
		system.debug('objectName.init  ' + objectName);
		if(fieldMappingSource.containsKey(objectName)){
			SObjectMapper.fieldMappingSource.remove(objectName);
		}
		SObjectMapper.fieldMappingSource.put(objectName, fieldMapping);
	}

	/**
	 * initializes mapping to be used in mapObject static method
	 * @param  fieldMapping
	 */
	public static void initialize(MapperConfigBuilder builder){
		IFieldMapping fieldMapping = builder.build();
		initialize(builder.getName(), fieldMapping);
	}


	public static Boolean isInitialized(String schemeName){
		return fieldMappingSource.containsKey(schemeName);
	}
	/**
	 * splits source into sobject map based on config from initialize method 
	 * @param  source
	 * @param  fieldMappingSource
	 * @param  mappedObjects
	 * @return returns map of sobjects "name of sobject" => "sobject"
	 */
	public static Map<String, SObject> mapObject(IResourceProvider source, Map<String, SObject> mappedObjects, String mappingName){
		String describeMappingName = String.isNotBlank(mappingName) ?  mappingName : source.getName();
		if(!SObjectMapper.fieldMappingSource.containsKey(describeMappingName)){
			throw new SplitException('Field mapping for this object is empty. Make sure SObjectMapper.initialize was invoked.');
		}
		IFieldMapping fieldMappingSource = SObjectMapper.fieldMappingSource.get(describeMappingName);
		Map<String, Set<String>> objectMapping = fieldMappingSource.getObjectMapping();
		Map<String, FieldMappingRule> fieldMapping = fieldMappingSource.getfieldMapping();
		Map<String, Schema.SObjectType> objectNameToObjectTypeMap = new Map<String,Schema.SObjectType>();
		Map<String, Map<String, Schema.SObjectField>> objectNameToFieldInfoMap = new Map<String, Map<String, Schema.SObjectField>>();
		String defaultObjectToMapName = fieldMappingSource.getDefaultMappingObject();
		if(!objectMapping.containsKey(defaultObjectToMapName) && String.isNotBlank(defaultObjectToMapName)){
			objectMapping.put(defaultObjectToMapName, new Set<String>());
		}
		for(String objectName: objectMapping.keySet()){
			Schema.SObjectType convertType = Schema.getGlobalDescribe().get(objectName);
			if(convertType == null){
				throw new SplitException('Cannot find sObject to split.');
			}
			objectNameToObjectTypeMap.put(objectName, convertType);
			objectNameToFieldInfoMap.put(objectName, convertType.getDescribe().fields.getMap());
		}
		
		for(String fieldToCopy : source.describeSource()){
			Boolean isCurrentFieldMapped = false;
			if(source.getValue(fieldToCopy) == null){
				continue;
			}
			String objectToMapName ='';
			if(String.IsNotBlank(fieldToCopy)){
				fieldToCopy = fieldToCopy.toLowerCase();
			}
			
			for(String objectName: objectMapping.keySet()){
				if(objectMapping.get(objectName).contains(fieldToCopy)){
					objectToMapName = objectName;
				}
			}
			if(String.IsNotBlank(defaultObjectToMapName) && String.IsBlank(objectToMapName)){
				objectToMapName = defaultObjectToMapName;
			}
			if(String.IsBlank(objectToMapName)){
				continue;
			}
			if(!mappedObjects.containsKey(objectToMapName)){
				system.debug('objectToMapName ' + objectToMapName);
				Schema.SObjectType convertType = objectNameToObjectTypeMap.get(objectToMapName);
				SObject genericObject = convertType.newSObject();
				mappedObjects.put(objectToMapName, genericObject);
			}
			string childObjectFieldName = fieldToCopy;
			object valueToWrite = source.getValue(fieldToCopy);

			if(fieldMapping.containsKey(fieldToCopy)){
				childObjectFieldName = fieldMapping.get(fieldToCopy).destination;
				IFieldFormatter formatter = fieldMapping.get(fieldToCopy).formatter;
				if(formatter != null){
					valueToWrite = formatter.format(valueToWrite);
				}
			}
			if(valueToWrite != null){
				try{
					//TBD: dirty approach, change 
					mappedObjects.get(objectToMapName).put(childObjectFieldName, valueToWrite);
				}catch(Exception e){
					Schema.DescribeFieldResult displayType;
					FormatterResult formatterResult;
					Boolean isLogError = false;
					if(!objectNameToFieldInfoMap.get(objectToMapName).containsKey(childObjectFieldName)){
						isLogError = true;
					}else{
						displayType = objectNameToFieldInfoMap.get(objectToMapName).get(childObjectFieldName).getDescribe();
						system.debug('field.displayType - ' + displayType.getType());
						IFieldFormatter formatter = FieldFormatterFactory.createFieldFormatter(displayType.getType());
						if(formatter != null){
							formatterResult = formatter.format(valueToWrite);
							system.debug('formatterResult ' + formatterResult);
							if(formatterResult.isSuccess){
								mappedObjects.get(objectToMapName).put(
									childObjectFieldName,
									formatterResult.data
								);
							}
						}
					}
					if(formatterResult == null || !formatterResult.isSuccess || isLogError){
						//TBD: add custom logger (posibility to mute debug output)
						system.debug('[error: ' +'from: ' + fieldToCopy + ' to ' + childObjectFieldName + ']' +e.getMessage());
						system.debug('\n' + e.getLineNumber());
						system.debug('\n' + e.getStackTraceString());
					}
				}
			}
		}
		return mappedObjects;
	}

	/**
	 * splits sobject into sobject map based on config from initialize method 
	 * @param  sObjectTomap
	 * @return returns map of sobjects "name of sobject" => "sobject"
	 */
	public static Map<String, SObject> mapObject(SObject sObjectTomap){
		return mapObject(new SObjectResourceProvider(sObjectTomap), new Map<String, sObject>(), '');
	}

	/**
	 * splits sobject into sobject map based on config from initialize method 
	 * @param  sobject
	 * @param  mappedObjects
	 * @return returns map of sobjects "name of sobject" => "sobject"
	 */
	public static Map<String, SObject> mapObject(SObject sObjectTomap, Map<String, sObject> mappedObjects){
		return mapObject(new SObjectResourceProvider(sObjectTomap), mappedObjects, '');
	}

	/**
	 * splits source into sobject map based on config from initialize method 
	 * @param  source
	 * @return returns map of sobjects "name of sobject" => "sobject"
	 */
	public static Map<String, SObject> mapObject(IResourceProvider source){
		return mapObject(source, new Map<String, sObject>(), '');
	}

	/**
	 * splits source into sobject map based on config from initialize method 
	 * @param  source
	 * @return returns map of sobjects "name of sobject" => "sobject"
	 */
	public static Map<String, SObject> mapObject(IResourceProvider source, String mappingName){
		return mapObject(source, new Map<String, sObject>(), mappingName);
	}
	
	/**
	 * splits source into sobject map based on config from initialize method 
	 * @param  source
	 * @return returns map of sobjects "name of sobject" => "sobject"
	 */
	public static Map<String, SObject> mapObject(IResourceProvider source, Map<String, sObject> mappedObjects){
		return mapObject(source, mappedObjects, '');
	}


	/**
	 * splits source into sobject map based on config from initialize method and return default entity 
	 * @param  source 
	 * @return 
	 */
	public static sObject mapSingleObject(SObject sobjectToMap){
		return mapSingleObject(new SObjectResourceProvider(sobjectToMap));
	}

	/**
	 * splits source into sobject map based on config from initialize method and return default entity 
	 * @param  source 
	 * @return 
	 */
	public static sObject mapSingleObject(IResourceProvider source){
		Map<String, SObject> result = SObjectMapper.mapObject(source);
		if(result.values().size() > 1){
			throw new SplitException('map ambiguity condition. Use mapSingleObject(String name) instead.');
		}
		return result.values()[0];
	}

	/**
	 * splits source into sobject map based on config from initialize method and return default entity 
	 * @param  source 
	 * @return 
	 */
	public static sObject mapSingleObject(SObject source, Map<String, sObject> mappedObjects){
		return mapSingleObject(new SObjectResourceProvider(source), mappedObjects);
	}

	/**
	 * splits source into sobject map based on config from initialize method and return default entity 
	 * @param  source 
	 * @return 
	 */
	public static sObject mapSingleObject(IResourceProvider source, Map<String, sObject> mappedObjects){
		Map<String, SObject> result = SObjectMapper.mapObject(source, mappedObjects);
		if(result.values().size() > 1){
			throw new SplitException('map ambiguity condition. Use mapSingleObject(String name) instead.');
		}
		return result.values()[0];
	}

	/**
	 * splits source into sobject map based on config from initialize method and return entity specified by name parameter 
	 * @param  source 
	 * @param  name - name of result object (note: note name of mapping config)
	 * @return 
	 */
	public static sObject mapSingleObject(IResourceProvider source, String name){
		return mapSingleObject(source, new Map<String, SObject>(), name);
	}

	/**
	 * splits source into sobject map based on config from initialize method and return entity specified by name parameter 
	 * @param  source
	 * @param  mappedObjects
	 * @param  name - name of result object (note: note name of mapping config)
	 * @return 
	 */
	public static sObject mapSingleObject(IResourceProvider source, Map<String, SObject> mappedObjects, String name){
		Map<String, SObject> result = SObjectMapper.mapObject(source, mappedObjects);
		if(result.containsKey(name)){
			return result.get(name);
		}else{
			throw new SplitException('Object is not found. Make sure that name is appropriate.');
		}
	}
	
	public class SplitException extends Exception{}
}