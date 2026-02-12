'use strict';

/**
 * Dialogflow Fulfillment Webhook for Travel Planner Chatbot
 * 
 * Features:
 * - Accommodation search by location
 * - Event search by type (Food, Music, Culture)
 * - Smart location normalization (handles abbreviations like KL, JB, KK)
 * - Sorted results by price (lowest first)
 * - Limited results (max 5) to prevent overwhelming responses
 * - Enhanced error handling and logging
 * - Rich formatted responses with pricing and details
 */

// 1. FIX: Point to the CORRECT project ID from your screenshot
const fastProjectId = 'fyp-project-7199d';

process.env.GCLOUD_PROJECT = fastProjectId;

const functions = require('firebase-functions');
const { WebhookClient } = require('dialogflow-fulfillment');
const admin = require('firebase-admin');

// 2. Initialize with the FYP project ID
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: fastProjectId
});

const db = admin.firestore();

exports.dialogflowFirebaseFulfillment = functions.https.onRequest((request, response) => {
  const agent = new WebhookClient({ request, response });

  async function handleAccommodation(agent) {
    let city = agent.parameters['location'];

    // Basic safety checks
    if (!city) {
      agent.add("Please specify a location. For example, try 'Penang' or 'Kuala Lumpur'.");
      return;
    }

    // Handle if location is an array (Dialogflow sometimes returns arrays)
    if (Array.isArray(city)) {
      // Filter out common words like "Find", "Show", "Suggest", etc.
      const filterWords = ['find', 'show', 'suggest', 'get', 'search', 'accommodation', 'hotel'];
      city = city.find(item => !filterWords.includes(item.toLowerCase())) || city[city.length - 1];
    }

    // Normalize city name for better matching
    city = normalizeLocationName(city);

    try {
        console.log(`[Accommodation Search] City: ${city}`);
        
        const accommodationRef = db.collection('accommodations');
        
        // Try exact match first
        let snapshot = await accommodationRef.where('location', '==', city).get();

        // If no exact match, try case-insensitive search
        if (snapshot.empty) {
            console.log(`[Accommodation Search] No exact match, trying case-insensitive`);
            const allAccommodations = await accommodationRef.get();
            const matches = [];
            
            allAccommodations.forEach(doc => {
                const data = doc.data();
                if (data.location && data.location.toLowerCase() === city.toLowerCase()) {
                    matches.push(data);
                }
            });

            if (matches.length === 0) {
                console.log(`[Accommodation Search] No results found for: ${city}`);
                agent.add(`Sorry, I couldn't find any accommodations in ${city}. 🏨\n\nTry these popular destinations:\n• Kuala Lumpur\n• Penang\n• Langkawi\n• Melaka\n• Johor Bahru\n• Kota Kinabalu`);
                return;
            }

            // Build response from matches
            formatAndSendResponse(agent, city, matches);
            return;
        }

        // Exact match found - convert to array
        const accommodations = [];
        snapshot.forEach(doc => {
            accommodations.push(doc.data());
        });

        console.log(`[Accommodation Search] Found ${accommodations.length} results`);
        formatAndSendResponse(agent, city, accommodations);

    } catch (error) {
        console.error("[Accommodation Search Error]:", error.message, error.stack);
        agent.add(`Sorry, I encountered an error while searching for accommodations. Please try again later.`);
    }
  }

  // Helper function to format and send accommodation response
  function formatAndSendResponse(agent, city, accommodations) {
    const MAX_RESULTS = 5; // Limit to prevent overwhelming response
    
    // Sort by price (lowest first)
    accommodations.sort((a, b) => {
        const priceA = parseFloat(a.price) || 0;
        const priceB = parseFloat(b.price) || 0;
        return priceA - priceB;
    });

    const totalCount = accommodations.length;
    const displayAccommodations = accommodations.slice(0, MAX_RESULTS);
    
    let responseText = `Found ${totalCount} accommodation${totalCount > 1 ? 's' : ''} in ${city}! 🏨\n\n`;
    
    displayAccommodations.forEach((data, index) => {
        const name = data.name || 'Hotel';
        const price = data.price ? `RM${data.price}` : 'Price N/A';
        
        responseText += `${index + 1}. ${name}\n`;
        responseText += `   💰 ${price}\n\n`;
    });

    // Add "more results" message if applicable
    if (totalCount > MAX_RESULTS) {
        responseText += `... and ${totalCount - MAX_RESULTS} more options available.`;
    }

    agent.add(responseText.trim());
  }

  // Event search handler
  async function handleEvent(agent) {
    let eventType = agent.parameters['event-type'];

    // Basic safety checks
    if (!eventType) {
      agent.add("Please specify an event type. For example, try 'Food', 'Music', or 'Culture' events.");
      return;
    }

    // Handle if event-type is an array
    if (Array.isArray(eventType)) {
      const filterWords = ['any', 'show', 'find', 'get', 'search', 'event', 'events'];
      eventType = eventType.find(item => !filterWords.includes(item.toLowerCase())) || eventType[eventType.length - 1];
    }

    // Normalize event type (capitalize first letter)
    eventType = String(eventType).trim();
    eventType = eventType.charAt(0).toUpperCase() + eventType.slice(1).toLowerCase();

    try {
        console.log(`[Event Search] Type: ${eventType}`);
        
        const eventRef = db.collection('Event');
        
        // Query by Type field
        let snapshot = await eventRef.where('Type', '==', eventType).get();

        if (snapshot.empty) {
            console.log(`[Event Search] No results found for: ${eventType}`);
            agent.add(`Sorry, I couldn't find any ${eventType} events at the moment. 🎉\n\nTry these categories:\n• Food\n• Music\n• Culture`);
            return;
        }

        // Collect events
        const events = [];
        snapshot.forEach(doc => {
            events.push(doc.data());
        });

        console.log(`[Event Search] Found ${events.length} results`);
        formatAndSendEventResponse(agent, eventType, events);

    } catch (error) {
        console.error("[Event Search Error]:", error.message, error.stack);
        agent.add(`Sorry, I encountered an error while searching for events. Please try again later.`);
    }
  }

  // Helper function to format and send event response
  function formatAndSendEventResponse(agent, eventType, events) {
    const MAX_RESULTS = 5;
    
    // Sort by date (upcoming first) and then by price
    events.sort((a, b) => {
        // Handle Firestore Timestamp objects
        let dateA = a.Date && a.Date.toDate ? a.Date.toDate() : new Date(a.Date);
        let dateB = b.Date && b.Date.toDate ? b.Date.toDate() : new Date(b.Date);
        
        if (dateA.getTime() !== dateB.getTime()) {
            return dateA - dateB;
        }
        return (parseFloat(a.Price) || 0) - (parseFloat(b.Price) || 0);
    });

    const totalCount = events.length;
    const displayEvents = events.slice(0, MAX_RESULTS);
    
    let responseText = `Found ${totalCount} ${eventType} event${totalCount > 1 ? 's' : ''}! 🎉\n\n`;
    
    displayEvents.forEach((data, index) => {
        const name = data.Name || 'Event';
        const price = data.Price ? `RM${data.Price}` : 'Free';
        const location = data.Location || 'Location TBA';
        
        // Convert Firebase Timestamp to readable date
        let date = 'Date TBA';
        if (data.Date) {
            try {
                // Check if it's a Firestore Timestamp
                if (data.Date.toDate) {
                    date = data.Date.toDate().toLocaleDateString('en-MY', { 
                        year: 'numeric', 
                        month: 'short', 
                        day: 'numeric' 
                    });
                } else if (typeof data.Date === 'string') {
                    date = new Date(data.Date).toLocaleDateString('en-MY', { 
                        year: 'numeric', 
                        month: 'short', 
                        day: 'numeric' 
                    });
                }
            } catch (error) {
                console.error('Date parsing error:', error);
                date = 'Date TBA';
            }
        }
        
        responseText += `${index + 1}. ${name}\n`;
        responseText += `   📍 ${location}\n`;
        responseText += `   📅 ${date}\n`;
        responseText += `   💰 ${price}\n\n`;
    });

    if (totalCount > MAX_RESULTS) {
        responseText += `... and ${totalCount - MAX_RESULTS} more events available.`;
    }

    agent.add(responseText.trim());
  }

  // Helper function to normalize location names
  function normalizeLocationName(location) {
    if (!location) return location;
    
    // Convert to string, trim, and remove extra spaces
    location = String(location).trim().replace(/\s+/g, ' ');
    
    // Common variations mapping - handles abbreviations and alternate spellings
    const locationMap = {
        // Kuala Lumpur variations
        'kl': 'Kuala Lumpur',
        'kuala lumpur': 'Kuala Lumpur',
        'k.l': 'Kuala Lumpur',
        'k.l.': 'Kuala Lumpur',
        
        // Johor Bahru variations
        'jb': 'Johor Bahru',
        'johor bahru': 'Johor Bahru',
        'johor': 'Johor Bahru',
        'j.b': 'Johor Bahru',
        
        // Penang variations
        'penang': 'Penang',
        'pulau pinang': 'Penang',
        'george town': 'Penang',
        'georgetown': 'Penang',
        
        // Melaka variations
        'melaka': 'Melaka',
        'malacca': 'Melaka',
        
        // Langkawi variations
        'langkawi': 'Langkawi',
        'pulau langkawi': 'Langkawi',
        
        // Kota Kinabalu variations
        'kota kinabalu': 'Kota Kinabalu',
        'kk': 'Kota Kinabalu',
        'kinabalu': 'Kota Kinabalu',
        'sabah': 'Kota Kinabalu',
        
        // Other cities
        'ipoh': 'Ipoh',
    };

    const lowerLocation = location.toLowerCase();
    return locationMap[lowerLocation] || location;
  }

  let intentMap = new Map();
  intentMap.set('Accommodation', handleAccommodation);
  intentMap.set('Event', handleEvent);
  
  return agent.handleRequest(intentMap);
});
