import React, { useState, useEffect } from 'react';

const API_BASE = '<API_GATEWAY_ENDPOINT>'; // e.g. https://xyz.execute-api.us-east-2.amazonaws.com/prod

/**
 * SearchForm collects date, zip, and criteria, then triggers onSearch.
 * It also fetches nearby courses based on geolocation.
 */
const SearchForm = ({ onSearch }) => {
  const [zip, setZip] = useState('');
  const [date, setDate] = useState('');
  const [criteria, setCriteria] = useState('');
  const [nearbyCourses, setNearbyCourses] = useState([]);

  useEffect(() => {
    // Auto-detect ZIP via geolocation
    if (!navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(async (position) => {
      // For demo: assume ZIP placeholder or reverse-geocode via API
      const detectedZip = zip || ''; // TODO: implement reverse-geocoding
      const res = await fetch(`${API_BASE}/search`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ zip: detectedZip, date, criteria })
      });
      const { courses } = await res.json();
      setNearbyCourses(courses);
    });
  }, []);

  const handleSearch = () => {
    onSearch({ zip, date, criteria });
  };

  return (
    <div className="search-form">
      <label>
        Date:
        <input
          type="date"
          value={date}
          onChange={(e) => setDate(e.target.value)}
        />
      </label>
      <label>
        Zip Code:
        <input
          type="text"
          placeholder="Enter zip"
          value={zip}
          onChange={(e) => setZip(e.target.value)}
        />
      </label>
      <label>
        Criteria:
        <input
          type="text"
          placeholder="Any criteria"
          value={criteria}
          onChange={(e) => setCriteria(e.target.value)}
        />
      </label>
      <button onClick={handleSearch}>Search</button>

      <h3>Nearby Courses</h3>
      <ul className="nearby-list">
        {nearbyCourses.map((course) => (
          <li key={course.courseId}>
            {course.name} — Rating: {course.rating}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default SearchForm;