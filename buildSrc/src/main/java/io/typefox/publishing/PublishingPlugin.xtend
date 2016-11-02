/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package io.typefox.publishing

import java.io.File
import org.gradle.api.GradleScriptException
import org.gradle.api.Plugin
import org.gradle.api.Project

class PublishingPlugin implements Plugin<Project> {
	
	static val EXTENSION_NAME = 'osspub'
	static val SIGNING_SECRET_KEYRING_FILE = 'signing.secretKeyRingFile'
	static val SIGNING_KEY_ID = 'signing.keyId'
	static val SIGNING_PASSWORD = 'signing.password'
	
	extension Project project
	PublishingPluginExtension osspub
	
	override apply(Project project) {
		this.project = project
		this.osspub = project.extensions.create(EXTENSION_NAME, PublishingPluginExtension)
		configurePlugins()
		configureProperties()
		val mavenPublishing = new MavenPublishing(project, osspub)
		val eclipsePublishing = new EclipsePublishing(project, osspub)
		project.afterEvaluate[
			mavenPublishing.configure()
			eclipsePublishing.configure()
		]
	}
	
	private def void configurePlugins() {
		buildscript => [
			repositories.jcenter()
			dependencies.add('classpath', 'pw.prok:download:3.1.3')
		]
		apply(#{'plugin' -> 'pw.prok.download'})
		apply(#{'plugin' -> 'signing'})
		apply(#{'plugin' -> 'maven-publish'})
	}
	
	private def void configureProperties() {
		val infoPrefix = EXTENSION_NAME.toUpperCase
		PublishingPluginExtension.declaredFields.filter[ field |
			// Get all extension fields that have an equally named setter method
			try {
				PublishingPluginExtension.getMethod(field.name, Object)
				true
			} catch (NoSuchMethodException e) {
				false
			}
		].forEach[ field |
			// Look for a property with the respective field name
			val propertyName = EXTENSION_NAME + '.' + field.name
			if (hasProperty(propertyName)) {
				logger.info('''«infoPrefix»: Using global property «propertyName»''')
				PublishingPluginExtension.getMethod(field.name, Object).invoke(osspub, property(propertyName))
			} else {
				// Look for an environment variable: field name in uppercase and using '_' as delimiter
				val envVarName = propertyName.toEnvVariable
				if (hasProperty(envVarName)) {
					logger.info('''«infoPrefix»: Using environment variable ORG_GRADLE_PROJECT_«envVarName»''')
					PublishingPluginExtension.getMethod(field.name, Object).invoke(osspub, property(envVarName))
				}
			}
		]
		
		if (osspub.version.nullOrEmpty)
			throw new GradleScriptException('''The version to be published has to be set with -P«EXTENSION_NAME».version=<version>''', null)
		
		// Configure credentials for the signing plugin
		val ext = project.extensions.extraProperties
		if (hasProperty(SIGNING_SECRET_KEYRING_FILE)) {
			logger.info('''«infoPrefix»: Using global property «SIGNING_SECRET_KEYRING_FILE»''')
		} else if (hasProperty(SIGNING_SECRET_KEYRING_FILE.toEnvVariable)) {
			val envVarName = SIGNING_SECRET_KEYRING_FILE.toEnvVariable
			logger.info('''«infoPrefix»: Using environment variable ORG_GRADLE_PROJECT_«envVarName»''')
			ext.set(SIGNING_SECRET_KEYRING_FILE, property(envVarName))
		} else {
			ext.set(SIGNING_SECRET_KEYRING_FILE, new File(System.getProperty('user.home'), '.gnupg/secring.gpg').toString)
		}
		if (hasProperty(SIGNING_KEY_ID)) {
			logger.info('''«infoPrefix»: Using global property «SIGNING_KEY_ID»''')
		} else if (hasProperty(SIGNING_KEY_ID.toEnvVariable)) {
			val envVarName = SIGNING_KEY_ID.toEnvVariable
			logger.info('''«infoPrefix»: Using environment variable ORG_GRADLE_PROJECT_«envVarName»''')
			ext.set(SIGNING_KEY_ID, property(envVarName))
		}
		if (hasProperty(SIGNING_PASSWORD)) {
			logger.info('''«infoPrefix»: Using global property «SIGNING_PASSWORD»''')
		} else if (hasProperty(SIGNING_PASSWORD.toEnvVariable)) {
			val envVarName = SIGNING_PASSWORD.toEnvVariable
			logger.info('''«infoPrefix»: Using environment variable ORG_GRADLE_PROJECT_«envVarName»''')
			ext.set(SIGNING_PASSWORD, property(envVarName))
		}
	}
	
	private static def toEnvVariable(String propertyName) {
		val result = new StringBuilder
		for (var i = 0; i < propertyName.length; i++) {
			val c = propertyName.charAt(i)
			if (Character.isLowerCase(c)) {
				result.append(Character.toUpperCase(c))
			} else if (Character.isUpperCase(c)) {
				result.append('_')
				result.append(c)
			} else {
				result.append('_')
			}
		}
		return result.toString
	}
	
}