import React from 'react';

/**
 * BookingPopup displays a list of available tee times and
 * allows the user to select one.
 */
const BookingPopup = ({ availableTimes = [], onTimeSelect, onClose }) => {
  return (
    <div className="popup-overlay">
      <div className="popup-content">
        <h2>Select a Tee Time</h2>
        <ul className="time-list">
          {availableTimes.map((time) => (
            <li key={time}>
              <button onClick={() => onTimeSelect(time)}>{time}</button>
            </li>
          ))}
        </ul>
        <button className="close-button" onClick={onClose}>
          Close
        </button>
      </div>
    </div>
  );
};

export default BookingPopup;
