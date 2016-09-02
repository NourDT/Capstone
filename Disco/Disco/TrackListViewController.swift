//
//  TrackListViewController.swift
//  Disco
//
//  Created by Tim on 8/25/16.
//  Copyright © 2016 Tim Chamberlin. All rights reserved.
//

import UIKit


let kTrackListDidLoad = "TrackListDidLoad"
let kUpNextListDidUpdate = "UpNextListDidUpdate"
let kTrackListDidRemoveSong = "TrackListDidUpdate"

class TrackListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, AddTrackToPlaylistDelegate, TrackTableViewCellDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var playlist: Playlist?
    var currentUser: User = UserController.sharedController.currentUser!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.registerNib(UINib(nibName: "TrackTableViewCell", bundle: nil), forCellReuseIdentifier: "trackCell")
        addTrackObservers(forPlaylistType: .Contributing)
    }
    
    deinit {
//        PlaylistController.sharedController.removeTrackObserverForPlaylist(playlist) { (success) in
//            
//        }
    }
    
    
    func addTrackObservers(forPlaylistType playlistType: PlaylistType) {
        guard let queue = playlist, currentUser = UserController.sharedController.currentUser else { return }
        PlaylistController.sharedController.addUpNextObserverToQueue(queue) { (track, didAdd) in
            if let track = track {
                if didAdd {
                    queue.upNext.append(track)
                    self.updateTableViewWithQueueData()
                    
                    // Add vote observers
                    TrackController.sharedController.getVoteStatusForTrackWithID(track.firebaseUID, inPlaylistWithID: queue.uid, ofType: playlistType, user: currentUser, completion: { (voteStatus, success) in
                        if success {
                            track.currentUserVoteStatus = voteStatus
                            self.updateTableViewWithQueueData()
                        }
                    })
                    TrackController.sharedController.attachVoteListener(forTrack: track, inPlaylist: queue, completion: { (newVoteCount, success) in
                        track.voteCount = newVoteCount
                        self.updateTableViewWithQueueData()
                    })
                    
                    
                    
                } else { // Track removed
                    queue.upNext = queue.upNext.filter { $0 != track }
                    self.updateTableViewWithQueueData()
                }
            }
        }
        
        
        // Add nowPlaying observer
        
        PlaylistController.sharedController.addNowPlayingObserverToQueue(queue, completion: { (track, didAdd) in
            guard let track = track else { return }
            if didAdd {
                queue.nowPlaying = track
                self.updateTableViewWithQueueData()
            } else {
                queue.nowPlaying = nil
                self.updateTableViewWithQueueData()
            }
        })
    }
    
    func updateTableViewWithQueueData() {
        guard let queue = playlist else { return }
        queue.upNext = TrackController.sortTracklistByVoteCount(queue.upNext)
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let playlist = playlist else { return 0 }
        if section == 0 {
            return playlist.nowPlaying != nil ? 1 : 0
        } else if section == 1 {
            return playlist.upNext.count
        }
        return 0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithIdentifier("trackCell", forIndexPath: indexPath) as? TrackTableViewCell, playlist = playlist else { return UITableViewCell() }
        
        if indexPath.section == 0 {
            if let nowPlaying = playlist.nowPlaying {
                let track = nowPlaying
                cell.track = track
                cell.voteStatus = track.currentUserVoteStatus
                cell.updateCellWithTrack(track)
                cell.votingStackView.hidden = true
                cell.delegate = self
            }
        } else if indexPath.section == 1 {
            if !playlist.upNext.isEmpty {
                let track = playlist.upNext[indexPath.row]
                cell.track = track
                cell.voteStatus = track.currentUserVoteStatus
                cell.updateCellWithTrack(track)
                cell.delegate = self
            }
        }
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Now Playing"
        } else if section == 1 {
            return "Up Next"
        } else {
            return ""
        }
    }
    
    // MARK: - Delegate Methods
    
    func didPressVoteButton(sender: TrackTableViewCell, voteType: VoteType) {
        guard let currentUser = UserController.sharedController.currentUser, playlist = playlist, track = sender.track else { return }
        
        TrackController.sharedController.user(currentUser, didVoteWithType: voteType, withVoteStatus: (sender.track?.currentUserVoteStatus)!, onTrack: track, inPlaylist: playlist, ofPlaylistType: .Contributing) { (success) in
            //
        }
    }
    
    func willAddTrackToPlaylist(track: Track) {
        
        track.playlistID = self.playlist!.uid
        PlaylistController.sharedController.addTrack(track, toQueue: self.playlist!) { (success) in
            // Fetch playlist tracks and reload tableView
            print("Update playlist with track: \(track.name)")
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "addTrackToPlaylistSegue" {
            let navVC = segue.destinationViewController as? UINavigationController
            guard let searchVC = navVC?.viewControllers.first as? SpotifySearchTableViewController else { return }
            searchVC.delegate = self
        }
    }
    
    @IBAction func addSongButtonTapped(sender: AnyObject) {
        self.performSegueWithIdentifier("addTrackToPlaylistSegue", sender: self)
    }
}