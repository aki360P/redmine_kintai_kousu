(function() {
  'use strict';

  function safeTrim(value) {
    return String(value || '').replace(/^\s+|\s+$/g, '');
  }

  function parseTimeToMinutes(timeStr) {
    if (!timeStr) {
      return null;
    }

    var value = safeTrim(timeStr);

    if (!value) {
      return null;
    }

    var hours;
    var minutes;

    if (value.indexOf(':') >= 0) {
      var parts = value.split(':');
      if (parts.length < 2 || parts[1] === '') {
        return null;
      }

      hours = parseInt(parts[0], 10);
      minutes = parseInt(parts[1], 10);
    } else if (value.indexOf('.') >= 0) {
      var floatHours = parseFloat(value);
      if (Number.isNaN(floatHours)) {
        return null;
      }

      hours = Math.floor(floatHours);
      minutes = Math.round((floatHours - hours) * 60);
    } else {
      hours = parseInt(value, 10);
      minutes = 0;
    }

    if (isNaN(hours) || isNaN(minutes)) {
      return null;
    }

    if (hours < 0 || minutes < 0 || minutes > 59) {
      return null;
    }

    return hours * 60 + minutes;
  }

  function normalizeEndMinutes(startMinutes, endMinutes) {
    if (endMinutes < startMinutes) {
      return endMinutes + 24 * 60;
    }

    return endMinutes;
  }

  function calculateNightMinutes(startMinutes, endMinutes) {
    var normalizedEnd = normalizeEndMinutes(startMinutes, endMinutes);
    var nightStart = 22 * 60;
    var nightEnd = 29 * 60;
    var total = 0;
    var rangeStart = startMinutes;
    var rangeEnd = normalizedEnd;

    if (rangeEnd <= rangeStart) {
      return 0;
    }

    var startDay = Math.floor((rangeStart - nightEnd) / (24 * 60));
    var endDay = Math.floor(rangeEnd / (24 * 60));

    for (var day = startDay; day <= endDay; day += 1) {
      var windowStart = nightStart + 24 * 60 * day;
      var windowEnd = nightEnd + 24 * 60 * day;
      var overlapStart = Math.max(rangeStart, windowStart);
      var overlapEnd = Math.min(rangeEnd, windowEnd);
      total += Math.max(0, overlapEnd - overlapStart);
    }

    return total;
  }

  function minutesToHoursString(minutes) {
    return (minutes / 60).toFixed(2);
  }

  function calculateAttendance(startTime, endTime, attribute) {
    var startMinutes = parseTimeToMinutes(startTime);
    var endMinutes = parseTimeToMinutes(endTime);

    if (startMinutes === null || endMinutes === null) {
      return null;
    }

    var normalizedEnd = normalizeEndMinutes(startMinutes, endMinutes);
    var durationMinutes = Math.max(0, normalizedEnd - startMinutes);
    var breakMinutes = 60;

    if (attribute === 'AM休' || attribute === 'PM休') {
      breakMinutes = 0;
    }

    var workMinutes = Math.max(0, durationMinutes - breakMinutes);
    var overtimeMinutes = Math.max(0, workMinutes - 8 * 60);
    var holidayMinutes = attribute === '休日出勤' ? workMinutes : 0;
    var nightMinutes = calculateNightMinutes(startMinutes, normalizedEnd);

    return {
      workMinutes: workMinutes,
      overtimeMinutes: overtimeMinutes,
      holidayMinutes: holidayMinutes,
      nightMinutes: nightMinutes
    };
  }

  function renderAttendanceCells() {
    var sourceCells = document.querySelectorAll('.kintai-attendance-cell[data-kind="start-time"]');
    var dataMap = window.kintaiAttendanceData || null;
    var totalWorkMinutes = 0;
    var totalOvertimeMinutes = 0;
    var totalHolidayMinutes = 0;
    var totalNightMinutes = 0;

    if (dataMap && typeof dataMap === 'object') {
      Object.keys(dataMap).forEach(function(dayKey) {
        var day = String(dayKey);
        var record = dataMap[dayKey] || {};
        var startTime = safeTrim(record.start_time);
        var endTime = safeTrim(record.end_time);
        var attribute = safeTrim(record.work_attribute);

        var workCell = document.querySelector('.kintai-attendance-cell[data-day="' + day + '"][data-kind="work-hours"]');
        var premiumCell = document.querySelector('.kintai-attendance-cell[data-day="' + day + '"][data-kind="premium"]');
        var workHoursEl = workCell ? workCell.querySelector('.kintai-work-hours') : null;
        var premiumEl = premiumCell ? premiumCell.querySelector('.kintai-premium') : null;

        if (!workHoursEl || !premiumEl) {
          return;
        }

        if (startTime === '-') {
          startTime = '';
        }

        if (endTime === '-') {
          endTime = '';
        }

        if (attribute === '-') {
          attribute = '';
        }

        var result = calculateAttendance(startTime, endTime, attribute);

        if (!result) {
          workHoursEl.textContent = '-';
          premiumEl.textContent = '-';
          return;
        }

        totalWorkMinutes += result.workMinutes;
        totalOvertimeMinutes += result.overtimeMinutes;
        totalHolidayMinutes += result.holidayMinutes;
        totalNightMinutes += result.nightMinutes;

        workHoursEl.textContent = minutesToHoursString(result.workMinutes);
        premiumEl.textContent = [
          minutesToHoursString(result.overtimeMinutes),
          minutesToHoursString(result.holidayMinutes),
          minutesToHoursString(result.nightMinutes)
        ].join(', ');
      });
    }

    for (var i = 0; i < sourceCells.length; i += 1) {
      if (dataMap) {
        continue;
      }
      var cell = sourceCells[i];
      var day = cell.getAttribute('data-day');
      var startCell = cell;
      var endCell = document.querySelector('.kintai-attendance-cell[data-day="' + day + '"][data-kind="end-time"]');
      var attributeCell = document.querySelector('.kintai-attendance-cell[data-day="' + day + '"][data-kind="attribute"]');
      var workCell = document.querySelector('.kintai-attendance-cell[data-day="' + day + '"][data-kind="work-hours"]');
      var premiumCell = document.querySelector('.kintai-attendance-cell[data-day="' + day + '"][data-kind="premium"]');

      var startText = startCell ? (startCell.textContent || startCell.innerText || '') : '';
      var endText = endCell ? (endCell.textContent || endCell.innerText || '') : '';
      var attributeText = attributeCell ? (attributeCell.textContent || attributeCell.innerText || '') : '';

      var startTime = safeTrim(startText);
      var endTime = safeTrim(endText);
      var attribute = safeTrim(attributeText);

      if (startTime === '-') {
        startTime = '';
      }

      if (endTime === '-') {
        endTime = '';
      }

      if (attribute === '-') {
        attribute = '';
      }
      var workHoursEl = workCell ? workCell.querySelector('.kintai-work-hours') : null;
      var premiumEl = premiumCell ? premiumCell.querySelector('.kintai-premium') : null;

      if (!workHoursEl || !premiumEl) {
        continue;
      }

      var result = calculateAttendance(startTime, endTime, attribute);

      if (!result) {
        workHoursEl.textContent = '-';
        premiumEl.textContent = '-';
        continue;
      }

      totalWorkMinutes += result.workMinutes;
      totalOvertimeMinutes += result.overtimeMinutes;
      totalHolidayMinutes += result.holidayMinutes;
      totalNightMinutes += result.nightMinutes;

      workHoursEl.textContent = minutesToHoursString(result.workMinutes);
      premiumEl.textContent = [
        minutesToHoursString(result.overtimeMinutes),
        minutesToHoursString(result.holidayMinutes),
        minutesToHoursString(result.nightMinutes)
      ].join(', ');
    }

    var totalWorkEl = document.querySelector('.kintai-total-work-hours');
    var totalPremiumEl = document.querySelector('.kintai-total-premium');

    if (totalWorkEl) {
      totalWorkEl.textContent = minutesToHoursString(totalWorkMinutes);
    }

    if (totalPremiumEl) {
      totalPremiumEl.textContent = [
        minutesToHoursString(totalOvertimeMinutes),
        minutesToHoursString(totalHolidayMinutes),
        minutesToHoursString(totalNightMinutes)
      ].join(', ');
    }
  }

  function scheduleRender() {
    renderAttendanceCells();
    setTimeout(renderAttendanceCells, 50);
  }

  document.addEventListener('DOMContentLoaded', scheduleRender);
  document.addEventListener('turbo:load', scheduleRender);
  document.addEventListener('turbolinks:load', scheduleRender);
  window.addEventListener('load', scheduleRender);
  scheduleRender();
})();
