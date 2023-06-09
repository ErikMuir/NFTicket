// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

struct ReservedSection {
  int256 ticketPrice;
}

struct ReservedSectionMap {
  string[] keys;
  mapping(string => ReservedSection) values;
  mapping(string => uint) indexOf;
  mapping(string => bool) inserted;
}

library ReservedSectionIterableMapping {
  function exists(ReservedSectionMap storage self, string memory key) internal view returns (bool) {
    return self.inserted[key];
  }

  function get(ReservedSectionMap storage self, string memory key) internal view returns (ReservedSection storage) {
    return self.values[key];
  }

  function getKeyAtIndex(ReservedSectionMap storage self, uint256 index) internal view returns (string storage) {
    return self.keys[index];
  }

  function size(ReservedSectionMap storage self) internal view returns (uint256) {
    return self.keys.length;
  }

  function set(ReservedSectionMap storage self, string memory key, ReservedSection memory val) internal {
    if (self.inserted[key]) {
      self.values[key] = val;
    } else {
      self.inserted[key] = true;
      self.values[key] = val;
      self.indexOf[key] = self.keys.length;
      self.keys.push(key);
    }
  }

  function remove(ReservedSectionMap storage self, string memory key) internal {
    if (!self.inserted[key]) {
      return;
    }

    delete self.inserted[key];
    delete self.values[key];

    uint index = self.indexOf[key];
    string memory lastKey = self.keys[self.keys.length - 1];

    self.indexOf[lastKey] = index;
    delete self.indexOf[key];

    self.keys[index] = lastKey;
    self.keys.pop();
  }
}
