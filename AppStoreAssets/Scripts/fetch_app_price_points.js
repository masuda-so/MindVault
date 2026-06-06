(() => {
  const APP_ID = "6776897058";

  function request(method, url) {
    const xhr = new XMLHttpRequest();
    xhr.open(method, url, false);
    xhr.withCredentials = true;
    xhr.setRequestHeader("Accept", "application/vnd.api+json");
    xhr.send(null);

    let response;
    try {
      response = JSON.parse(xhr.responseText || "{}");
    } catch {
      response = xhr.responseText;
    }

    return { method, url, status: xhr.status, response };
  }

  const base = "https://appstoreconnect.apple.com/iris/v1";
  const schedule = request("GET", `${base}/apps/${APP_ID}/appPriceSchedule?include=baseTerritory,manualPrices,automaticPrices&limit[manualPrices]=50&limit[automaticPrices]=50`);
  const pricePoints = request("GET", `${base}/apps/${APP_ID}/appPricePoints?include=territory&filter[territory]=USA&limit=200`);
  const relationshipPricePoints = request("GET", `${base}/apps/${APP_ID}/relationships/appPricePoints?filter[territory]=USA&limit=200`);

  function summarizePricePoint(point) {
    return {
      id: point.id,
      customerPrice: point.attributes && point.attributes.customerPrice,
      proceeds: point.attributes && point.attributes.proceeds,
      relationships: point.relationships
    };
  }

  return JSON.stringify({
    schedule: {
      status: schedule.status,
      data: schedule.response.data,
      included: schedule.response.included,
      errors: schedule.response.errors
    },
    pricePoints: {
      status: pricePoints.status,
      count: (pricePoints.response.data || []).length,
      points: (pricePoints.response.data || []).map(summarizePricePoint).slice(0, 50),
      errors: pricePoints.response.errors
    },
    relationshipPricePoints: {
      status: relationshipPricePoints.status,
      count: (relationshipPricePoints.response.data || []).length,
      data: (relationshipPricePoints.response.data || []).slice(0, 50),
      errors: relationshipPricePoints.response.errors
    }
  }, null, 2);
})();
